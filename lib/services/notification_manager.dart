import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Evaluates the contextual notification triggers from the user's logged data
/// and decides what to fire, deduping each alert to once per day. Pure
/// coordination — it reads values passed in (no Firestore) and drives
/// [NotificationService].
///
/// Trigger reference:
///   • Calorie surplus    — consumed > 115% of calorie target
///   • Low protein        — protein < 70% of target (scheduled 8 PM + evening)
///   • Goal achieved      — every macro within ±10% of target
///   • Skipped meal       — nothing logged by mid-afternoon
///   • Hydration          — fixed daytime nudges (water isn't logged yet, so
///                          these aren't data-driven until water logging exists)
class NotificationManager {
  NotificationManager({NotificationService? service})
      : _service = service ?? NotificationService.instance;

  final NotificationService _service;

  // Stable notification ids (kept distinct so each can be updated/cancelled).
  static const _idSurplus = 1001;
  static const _idGoal = 1002;
  static const _idLowProteinNow = 1003;
  static const _idLowProteinSched = 1004;
  static const _idSkipped = 1005;
  static const _idHydration1 = 1010;
  static const _idHydration2 = 1011;
  static const _idHydration3 = 1012;
  static const _idTest = 9999;

  static final DateFormat _dayKey = DateFormat('yyyy-MM-dd');

  bool _ready = false;

  /// Initialise the plugin, request permission, and lay down the fixed
  /// hydration reminders. Safe to call more than once.
  Future<void> init() async {
    if (_ready) return;
    await _service.init();
    await _service.requestPermission();
    await _setupHydrationReminders();
    _ready = true;
  }

  Future<void> _setupHydrationReminders() async {
    await _service.scheduleDaily(
      id: _idHydration1,
      hour: 11,
      minute: 0,
      title: 'Hydration',
      body: 'Time to hydrate! Aim for another 500 ml. 💧',
    );
    await _service.scheduleDaily(
      id: _idHydration2,
      hour: 15,
      minute: 0,
      title: 'Hydration',
      body: 'Water break — keep it topped up. 💧',
    );
    await _service.scheduleDaily(
      id: _idHydration3,
      hour: 19,
      minute: 0,
      title: 'Hydration',
      body: 'Evening hydration check — another glass? 💧',
    );
  }

  /// Evaluate the data-driven triggers. Call whenever today's totals change.
  Future<void> evaluate({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required int targetCalories,
    required int targetProtein,
    required int targetCarbs,
    required int targetFat,
    DateTime? nowOverride,
  }) async {
    if (targetCalories <= 0) return; // targets not set up yet
    final now = nowOverride ?? DateTime.now();

    // ── Calorie surplus: > 115% of target ──
    if (calories > targetCalories * 1.15) {
      final over = calories - targetCalories;
      await _fireOncePerDay(
        'surplus',
        _idSurplus,
        'Over your calorie goal',
        "You're $over kcal over your goal today.",
      );
    }

    // ── Goal achieved: every macro within ±10% ──
    final allOnTarget = _within(calories, targetCalories) &&
        _within(protein, targetProtein) &&
        _within(carbs, targetCarbs) &&
        _within(fat, targetFat);
    if (allOnTarget) {
      await _fireOncePerDay(
        'goal',
        _idGoal,
        'Goal achieved 🎯',
        'Great day — all macro targets hit!',
      );
    }

    // ── Low protein: < 70% of target ──
    if (targetProtein > 0 && protein < targetProtein * 0.70) {
      final gap = targetProtein - protein;
      final body = "${gap}g short — try Greek yogurt or canned tuna.";
      // Best-effort 8 PM reminder (fires even if the app is closed), refreshed
      // with the latest gap each time the data changes.
      await _service.scheduleDaily(
        id: _idLowProteinSched,
        hour: 20,
        minute: 0,
        title: 'Low on protein',
        body: body,
      );
      // If it's already evening and the app is open, nudge now too.
      if (now.hour >= 20) {
        await _fireOncePerDay('lowprotein', _idLowProteinNow,
            'Low on protein', body);
      }
    } else {
      // Hit the threshold — don't let the scheduled reminder fire.
      await _service.cancel(_idLowProteinSched);
    }

    // ── Skipped meal: nothing logged by mid-afternoon ──
    if (now.hour >= 14 && calories == 0) {
      await _fireOncePerDay(
        'skipped',
        _idSkipped,
        'Did you eat?',
        "Haven't logged any meals yet today — did you eat?",
      );
    }
  }

  /// Manual test hook (wired to the dashboard bell) so users can confirm
  /// notifications are enabled on their device.
  Future<void> sendTest() async {
    await _service.requestPermission();
    await _service.showNow(
      id: _idTest,
      title: 'NutriFit',
      body: 'Notifications are working! 🎉',
    );
  }

  bool _within(int value, int target) =>
      target > 0 && (value - target).abs() <= target * 0.10;

  /// Fire [id] only if this alert type hasn't fired yet today.
  Future<void> _fireOncePerDay(
      String type, int id, String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notif_fired_$type';
    final today = _dayKey.format(DateTime.now());
    if (prefs.getString(key) == today) return;
    await _service.showNow(id: id, title: title, body: body);
    await prefs.setString(key, today);
  }
}
