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

  /// The cuisines a user can ask for more of. Stored values match these labels.
  static const cuisineOptions = ['Malay', 'Chinese', 'Indian', 'Thai', 'Western'];

  List<DayPlan> days = const [];
  DateTime? plannedAt;
  bool isLoading = true;
  bool isRefreshing = false;
  String? error;

  /// Cuisines the user wants more of; empty = balanced mix. Applied on the next
  /// regenerate (and by the background job, since it's persisted to the cache).
  final Set<String> cuisines = {};

  bool get isEmpty => days.isEmpty;

  Future<void> load() async {
    days = await _cache.readPlan();
    plannedAt = await _cache.plannedAt();
    cuisines
      ..clear()
      ..addAll(await _cache.readCuisines());
    isLoading = false;
    notifyListeners();
  }

  /// Toggle a cuisine preference and persist it. Does NOT auto-regenerate —
  /// the user picks what they want, then taps regenerate to apply.
  Future<void> toggleCuisine(String cuisine) async {
    if (!cuisines.remove(cuisine)) cuisines.add(cuisine);
    notifyListeners();
    await _cache.saveCuisines(cuisines.toList());
  }

  /// "Mixed" = no specific bias: clear all picks so the plan spreads evenly
  /// across every cuisine. Selected state is simply `cuisines.isEmpty`.
  Future<void> setMixed() async {
    if (cuisines.isEmpty) return;
    cuisines.clear();
    notifyListeners();
    await _cache.saveCuisines(const []);
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
      // Log the real cause — the on-screen text is intentionally short, so
      // without this the actual API/parse error is invisible to developers.
      debugPrint('Meal plan generation failed: $e');
      error = _friendly(e);
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  String _friendly(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('api key')) return 'AI key not configured for this build.';
    // Quota / billing exhaustion (HTTP 429 RESOURCE_EXHAUSTED). Retrying won't
    // help until the key has quota, so say so plainly instead of "try again".
    if (s.contains('quota') ||
        s.contains('exhausted') ||
        s.contains('credits') ||
        s.contains('billing') ||
        s.contains('rate limit') ||
        s.contains('429')) {
      return 'AI usage limit reached — check the Gemini API billing/quota.';
    }
    if (s.contains('timed out') || s.contains('timeout')) {
      return 'Timed out — check your connection and try again.';
    }
    return 'Could not generate a plan. Please try again.';
  }
}
