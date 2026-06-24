import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_prefs.dart';
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
///   • Hydration          — fixed daytime reminders + data-driven nudge when
///                          falling behind the daily water goal
///   • Activity           — fixed daytime "get moving" reminders + data-driven
///                          nudge/celebration around the daily step goal
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
  static const _idHydrationNow = 1013;
  static const _idActivity1 = 1020;
  static const _idActivity2 = 1021;
  static const _idActivityGoal = 1022;
  static const _idActivityBehind = 1023;
  static const _idTest = 9999;

  static final DateFormat _dayKey = DateFormat('yyyy-MM-dd');

  bool _ready = false;

  /// Initialise the plugin, request permission, and lay down the fixed
  /// hydration reminders. Safe to call more than once.
  Future<void> init() async {
    if (_ready) return;
    await _service.init();
    await _service.requestPermission();
    await applyScheduledReminders();
    _ready = true;
  }

  /// Lay down the fixed daily reminders for each enabled category and cancel
  /// them for disabled ones. Call on init and whenever the user changes their
  /// notification settings so toggles take effect immediately.
  Future<void> applyScheduledReminders() async {
    if (await NotificationPrefs.hydrationEnabled()) {
      await _setupHydrationReminders();
    } else {
      await _service.cancel(_idHydration1);
      await _service.cancel(_idHydration2);
      await _service.cancel(_idHydration3);
    }

    if (await NotificationPrefs.activityEnabled()) {
      await _setupActivityReminders();
    } else {
      await _service.cancel(_idActivity1);
      await _service.cancel(_idActivity2);
    }

    // Food has no fixed daily reminder except the conditional low-protein one;
    // make sure it can't fire while the category is off.
    if (!await NotificationPrefs.foodEnabled()) {
      await _service.cancel(_idLowProteinSched);
    }
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

  Future<void> _setupActivityReminders() async {
    await _service.scheduleDaily(
      id: _idActivity1,
      hour: 12,
      minute: 0,
      title: 'Time to move',
      body: 'Halfway through the day — get some steps in! 🚶',
    );
    await _service.scheduleDaily(
      id: _idActivity2,
      hour: 18,
      minute: 0,
      title: 'Time to move',
      body: 'An evening walk will help you hit your step goal. 🚶',
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
    double waterLitres = 0,
    double waterGoalLitres = 0,
    DateTime? nowOverride,
  }) async {
    final now = nowOverride ?? DateTime.now();

    // The macro-based triggers below need a calorie target; hydration (further
    // down) is independent of nutrition setup, so it runs regardless. Each
    // category is also gated behind the user's notification settings.
    if (targetCalories > 0 && await NotificationPrefs.foodEnabled()) {
      await _evaluateNutrition(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        targetCalories: targetCalories,
        targetProtein: targetProtein,
        targetCarbs: targetCarbs,
        targetFat: targetFat,
        now: now,
      );
    }

    // ── Hydration: data-driven from logged water ──
    if (waterGoalLitres > 0 && await NotificationPrefs.hydrationEnabled()) {
      if (waterLitres >= waterGoalLitres) {
        // Goal met — silence today's hydration reminders.
        await _service.cancel(_idHydration1);
        await _service.cancel(_idHydration2);
        await _service.cancel(_idHydration3);
      } else {
        // Re-arm the fixed daily reminders in case they were cancelled on a
        // previous day when the goal was met (cancelling a daily-repeating
        // notification removes all future occurrences, not just today's).
        await _setupHydrationReminders();

        // Nudge if it's daytime and 2h+ since the last water log (throttled
        // to at most one nudge every 2h).
        final prefs = await SharedPreferences.getInstance();
        final nowMs = now.millisecondsSinceEpoch;
        const twoHours = 2 * 60 * 60 * 1000;
        final lastWater = prefs.getInt('last_water_log_ms') ?? 0;
        final lastNudge = prefs.getInt('notif_hydration_last_ms') ?? 0;
        final daytime = now.hour >= 9 && now.hour < 21;
        if (daytime &&
            nowMs - lastWater >= twoHours &&
            nowMs - lastNudge >= twoHours) {
          await _service.showNow(
            id: _idHydrationNow,
            title: 'Time to hydrate',
            body: "You're at ${waterLitres.toStringAsFixed(1)}L of "
                "${waterGoalLitres.toStringAsFixed(1)}L today — grab a glass! 💧",
          );
          await prefs.setInt('notif_hydration_last_ms', nowMs);
        }
      }
    }
  }

  /// Macro / calorie triggers — only meaningful once nutrition targets exist.
  Future<void> _evaluateNutrition({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required int targetCalories,
    required int targetProtein,
    required int targetCarbs,
    required int targetFat,
    required DateTime now,
  }) async {
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

  /// Evaluate activity (step) triggers against today's step count. Call when
  /// the live step total changes (throttled by the caller). [stepGoal] is the
  /// user's daily step target.
  ///
  ///   • Goal achieved  — steps reached the daily goal (celebrated once/day)
  ///   • Behind         — evening and under half the goal (nudged once/day)
  Future<void> evaluateActivity({
    required int steps,
    required int stepGoal,
    DateTime? nowOverride,
  }) async {
    if (stepGoal <= 0) return; // no goal configured
    if (!await NotificationPrefs.activityEnabled()) return;
    final now = nowOverride ?? DateTime.now();

    if (steps >= stepGoal) {
      // Goal met — silence today's fixed "get moving" reminders and celebrate.
      await _service.cancel(_idActivity1);
      await _service.cancel(_idActivity2);
      await _fireOncePerDay(
        'activitygoal',
        _idActivityGoal,
        'Step goal smashed! 🏆',
        "You hit $stepGoal steps today — nice work!",
      );
      return;
    }

    // Goal not met — re-arm the fixed daily reminders in case they were
    // cancelled on a previous day when the goal was reached (cancelling a
    // daily-repeating notification removes all future occurrences).
    await _setupActivityReminders();

    // Behind nudge: in the evening and still under half the goal.
    if (now.hour >= 18 && steps < stepGoal * 0.5) {
      final left = stepGoal - steps;
      await _fireOncePerDay(
        'activitybehind',
        _idActivityBehind,
        'Get moving 🚶',
        "You're at $steps steps — $left to go before bed. A short walk helps!",
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
