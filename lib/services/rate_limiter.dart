import 'package:shared_preferences/shared_preferences.dart';

/// Result of a rate-limit check.
class RateLimitResult {
  final bool allowed;
  final Duration? retryAfter;
  final String? message;

  const RateLimitResult.allow()
      : allowed = true,
        retryAfter = null,
        message = null;

  const RateLimitResult.deny(this.retryAfter, this.message) : allowed = false;
}

/// Lightweight client-side rate limiter backed by [SharedPreferences].
///
/// Enforces two independent rules so a runaway loop or an impatient user can't
/// hammer an external API (protecting both quota and cost):
///   • [minInterval] — a cooldown between consecutive requests.
///   • [maxRequests] within a rolling [window] — an absolute cap.
///
/// Timestamps persist on disk, so the limit survives the app being killed and
/// can't be bypassed by simply restarting.
///
/// NOTE: This is a client-side guard for UX and accidental abuse. It is not a
/// substitute for server-side enforcement — a determined attacker who extracts
/// the API key can bypass it. The real fix is to proxy the API behind a backend
/// (e.g. a Cloud Function) that holds the key and rate-limits per user.
class RateLimiter {
  RateLimiter({
    required this.storageKey,
    this.minInterval = const Duration(seconds: 3),
    this.maxRequests = 20,
    this.window = const Duration(hours: 1),
  });

  /// Unique SharedPreferences key so multiple limiters don't collide.
  final String storageKey;
  final Duration minInterval;
  final int maxRequests;
  final Duration window;

  List<int> _recentTimestamps(SharedPreferences prefs, int now) {
    final cutoff = now - window.inMilliseconds;
    return (prefs.getStringList(storageKey) ?? const [])
        .map((s) => int.tryParse(s) ?? 0)
        .where((t) => t > cutoff)
        .toList()
      ..sort();
  }

  /// Checks whether a request is allowed right now. Does not consume a slot —
  /// call [record] when the request is actually made.
  Future<RateLimitResult> check() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamps = _recentTimestamps(prefs, now);

    // ── Cooldown between requests ──
    if (timestamps.isNotEmpty) {
      final sinceLast = now - timestamps.last;
      if (sinceLast < minInterval.inMilliseconds) {
        final wait = minInterval.inMilliseconds - sinceLast;
        return RateLimitResult.deny(
          Duration(milliseconds: wait),
          'Please wait a moment before scanning again.',
        );
      }
    }

    // ── Absolute cap within the rolling window ──
    if (timestamps.length >= maxRequests) {
      final wait = (timestamps.first + window.inMilliseconds) - now;
      return RateLimitResult.deny(
        Duration(milliseconds: wait),
        "You've reached the scan limit. Try again in "
            '${_humanize(Duration(milliseconds: wait))}.',
      );
    }

    return const RateLimitResult.allow();
  }

  /// Records that a request was made (consumes a slot in the window).
  Future<void> record() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamps = _recentTimestamps(prefs, now)..add(now);
    await prefs.setStringList(
      storageKey,
      timestamps.map((e) => e.toString()).toList(),
    );
  }

  String _humanize(Duration d) {
    if (d.inMinutes >= 1) return '${d.inMinutes} min';
    return '${d.inSeconds.clamp(1, 60)} sec';
  }
}
