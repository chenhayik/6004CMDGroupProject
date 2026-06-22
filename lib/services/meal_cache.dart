import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_plan.dart';

/// Local store shared between the foreground app and the Workmanager background
/// isolate. Holds the generated week plus a small "mirror" of the inputs the
/// background job needs.
///
/// Uses `SharedPreferencesAsync` (NOT a third-party DB). On Android this API is
/// implemented on top of **Jetpack DataStore**, and it reads/writes the
/// platform store on every call (no Dart-side cache) — so it's safe to use from
/// both the foreground and the background isolate, which is exactly what the
/// offline meal-plan pipeline needs.
class MealCache {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static const _kTargets = 'mealplan_targets';
  static const _kRecent = 'mealplan_recent';
  static const _kWeek = 'mealplan_week';
  static const _kPlannedAt = 'mealplan_planned_at';

  // ── Inputs mirror (written by the foreground app) ──
  Future<void> saveInputsMirror({
    required int kcal,
    required int protein,
    required int carbs,
    required int fat,
    required String goal,
    required List<String> recentMeals,
  }) async {
    await _prefs.setString(
      _kTargets,
      jsonEncode({
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'goal': goal,
      }),
    );
    await _prefs.setString(_kRecent, jsonEncode(recentMeals));
  }

  Future<Map<String, dynamic>?> readTargets() async {
    final s = await _prefs.getString(_kTargets);
    return s == null ? null : jsonDecode(s) as Map<String, dynamic>;
  }

  Future<List<String>> readRecentMeals() async {
    final s = await _prefs.getString(_kRecent);
    return s == null ? const [] : List<String>.from(jsonDecode(s) as List);
  }

  // ── Weekly plan (written by the background job) ──
  Future<void> savePlan(List<DayPlan> days, DateTime plannedAt) async {
    await _prefs.setString(
        _kWeek, jsonEncode(days.map((d) => d.toMap()).toList()));
    await _prefs.setString(
        _kPlannedAt, plannedAt.millisecondsSinceEpoch.toString());
  }

  Future<List<DayPlan>> readPlan() async {
    final s = await _prefs.getString(_kWeek);
    if (s == null) return const [];
    final list = jsonDecode(s) as List;
    return list
        .whereType<Map>()
        .map((m) => DayPlan.fromMap(m.cast<String, dynamic>()))
        .toList();
  }

  Future<DateTime?> plannedAt() async {
    final s = await _prefs.getString(_kPlannedAt);
    final ms = s == null ? null : int.tryParse(s);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
