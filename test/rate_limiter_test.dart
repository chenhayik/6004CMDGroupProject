import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_application_group/services/rate_limiter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // RateLimiter reads/writes SharedPreferences, so route it to an in-memory map.
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now().millisecondsSinceEpoch;
  int agoMs(Duration d) => now - d.inMilliseconds;

  group('check — empty / fresh store', () {
    test('allows the first request when nothing is recorded', () async {
      SharedPreferences.setMockInitialValues({});
      final rl = RateLimiter(storageKey: 'k');
      final r = await rl.check();
      expect(r.allowed, isTrue);
      expect(r.retryAfter, isNull);
    });
  });

  group('record', () {
    test('persists a timestamp slot', () async {
      SharedPreferences.setMockInitialValues({});
      final rl = RateLimiter(storageKey: 'k');
      await rl.record();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('k'), hasLength(1));
    });
  });

  group('cooldown (minInterval)', () {
    test('denies a request fired inside the cooldown window', () async {
      SharedPreferences.setMockInitialValues({
        'k': ['$now'], // a request "just now"
      });
      final rl = RateLimiter(
        storageKey: 'k',
        minInterval: const Duration(seconds: 10),
        maxRequests: 100, // keep the cap out of the way
      );
      final r = await rl.check();
      expect(r.allowed, isFalse);
      expect(r.retryAfter, isNotNull);
    });

    test('allows once the cooldown has elapsed (still within the window)',
        () async {
      SharedPreferences.setMockInitialValues({
        'k': ['${agoMs(const Duration(seconds: 20))}'],
      });
      final rl = RateLimiter(
        storageKey: 'k',
        minInterval: const Duration(seconds: 10),
        maxRequests: 100,
      );
      final r = await rl.check();
      expect(r.allowed, isTrue);
    });
  });

  group('rolling-window cap (maxRequests)', () {
    test('denies once the cap is reached within the window', () async {
      SharedPreferences.setMockInitialValues({
        'k': ['$now', '$now', '$now'], // 3 recent requests
      });
      final rl = RateLimiter(
        storageKey: 'k',
        minInterval: Duration.zero, // isolate the cap from the cooldown
        maxRequests: 3,
        window: const Duration(hours: 1),
      );
      final r = await rl.check();
      expect(r.allowed, isFalse);
      expect(r.retryAfter, isNotNull);
    });

    test('allows when still under the cap', () async {
      SharedPreferences.setMockInitialValues({
        'k': ['$now', '$now'], // only 2 of 3
      });
      final rl = RateLimiter(
        storageKey: 'k',
        minInterval: Duration.zero,
        maxRequests: 3,
        window: const Duration(hours: 1),
      );
      final r = await rl.check();
      expect(r.allowed, isTrue);
    });

    test('timestamps older than the window are ignored', () async {
      SharedPreferences.setMockInitialValues({
        // Three hits, but all 2 h ago with a 1 h window → effectively none.
        'k': [
          '${agoMs(const Duration(hours: 2))}',
          '${agoMs(const Duration(hours: 2))}',
          '${agoMs(const Duration(hours: 2))}',
        ],
      });
      final rl = RateLimiter(
        storageKey: 'k',
        minInterval: Duration.zero,
        maxRequests: 1,
        window: const Duration(hours: 1),
      );
      final r = await rl.check();
      expect(r.allowed, isTrue);
    });
  });
}
