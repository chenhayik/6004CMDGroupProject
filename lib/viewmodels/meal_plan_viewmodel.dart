import 'package:flutter/foundation.dart';

import '../models/meal_plan.dart';
import '../services/meal_cache.dart';
import '../services/meal_planner.dart';

class MealPlanViewModel extends ChangeNotifier {
  MealPlanViewModel({MealCache? cache, MealPlanner? planner})
      : _cache = cache ?? MealCache(),
        _planner = planner ?? MealPlanner() {
    load();
  }

  final MealCache _cache;
  final MealPlanner _planner;

  List<DayPlan> days = const [];
  DateTime? plannedAt;
  bool isLoading = true;
  bool isRefreshing = false;
  String? error;

  bool get isEmpty => days.isEmpty;

  Future<void> load() async {
    days = await _cache.readPlan();
    plannedAt = await _cache.plannedAt();
    isLoading = false;
    notifyListeners();
  }

  /// Generate a fresh plan now (online) and re-arm the offline notifications.
  Future<void> refresh() async {
    isRefreshing = true;
    error = null;
    notifyListeners();
    try {
      final generated = await _planner.runWeeklyPlan(force: true);
      if (!generated) {
        error = 'Set up your nutrition targets first.';
      }
      await load();
    } catch (e) {
      error = _friendly(e);
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('api key')) return 'AI key not configured for this build.';
    if (s.contains('timed out') || s.contains('timeout')) {
      return 'Timed out — check your connection and try again.';
    }
    return 'Could not generate a plan. Please try again.';
  }
}
