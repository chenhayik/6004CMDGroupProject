import 'package:flutter/foundation.dart';

import '../models/meal_plan.dart';
import 'gemini_meal_plan_service.dart';
import 'meal_cache.dart';
import 'notification_service.dart';

/// Orchestrates the offline meal-plan pipeline: read the locally-mirrored
/// inputs → ask Gemini for the week → cache it → pre-schedule one notification
/// per meal so they fire completely offline. Runs in both the foreground
/// (manual refresh) and the Workmanager background isolate.
class MealPlanner {
  MealPlanner({
    MealCache? cache,
    GeminiMealPlanService? gemini,
    NotificationService? notifications,
  })  : _cache = cache ?? MealCache(),
        _gemini = gemini ?? GeminiMealPlanService(),
        _notif = notifications ?? NotificationService.instance;

  final MealCache _cache;
  final GeminiMealPlanService _gemini;
  final NotificationService _notif;

  // Notification id range reserved for meal reminders (clear of the 1001–1013
  // contextual alerts): 7 days × 3 meals = 21 → 2000..2020.
  static const int baseId = 2000;
  static const int _slots = 3;
  static const Map<String, List<int>> _times = {
    'breakfast': [8, 0],
    'lunch': [12, 0],
    'dinner': [18, 0],
  };

  /// Returns true if a new plan was generated. Skips work when the cached plan
  /// is still fresh (< 6 days old) unless [force] is set.
  Future<bool> runWeeklyPlan({bool force = false}) async {
    final plannedAt = await _cache.plannedAt();
    if (!force &&
        plannedAt != null &&
        DateTime.now().difference(plannedAt).inDays < 6) {
      return false; // still fresh
    }

    final targets = await _cache.readTargets();
    if (targets == null) {
      debugPrint('MealPlanner: no targets mirrored yet — skipping.');
      return false;
    }
    final recent = await _cache.readRecentMeals();

    final days = await _gemini.generateWeek(
      kcal: _int(targets['kcal']),
      protein: _int(targets['protein']),
      carbs: _int(targets['carbs']),
      fat: _int(targets['fat']),
      goal: (targets['goal'] ?? 'maintain').toString(),
      recentMealNames: recent,
    );

    final now = DateTime.now();
    await _cache.savePlan(days, now);
    await scheduleAll(days, now);
    return true;
  }

  /// (Re)schedule one offline notification per meal, baking the meal into each.
  Future<void> scheduleAll(List<DayPlan> days, DateTime base) async {
    for (var i = baseId; i <= baseId + (7 * _slots) - 1; i++) {
      await _notif.cancel(i);
    }

    var id = baseId;
    for (final day in days) {
      for (final meal in day.meals) {
        final t = _times[meal.slot.toLowerCase()] ?? const [8, 0];
        final when = DateTime(
            base.year, base.month, base.day + day.dayOffset, t[0], t[1]);
        if (when.isAfter(DateTime.now())) {
          final macros = '${meal.calories} kcal · '
              'P${meal.proteinG} C${meal.carbsG} F${meal.fatG}';
          await _notif.scheduleOneShotAt(
            id: id,
            when: when,
            title: '${_cap(meal.slot)}: ${meal.name}',
            body: meal.isWildcard ? '🎲 Treat day — $macros' : macros,
          );
        }
        id++;
      }
    }
  }

  /// If the OS dropped scheduled alarms (e.g. after a reboot) but we still hold
  /// a valid cached plan, re-arm the upcoming notifications from cache.
  Future<void> rescheduleFromCacheIfNeeded() async {
    final plannedAt = await _cache.plannedAt();
    final days = await _cache.readPlan();
    if (plannedAt == null || days.isEmpty) return;
    await scheduleAll(days, plannedAt);
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? 0;
  }
}
