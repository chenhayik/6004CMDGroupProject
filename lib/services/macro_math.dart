import 'dart:math';

/// Macro split as percentages of total calories: (protein, carbs, fat).
/// Should sum to 1.0.
typedef MacroSplit = (double protein, double carbs, double fat);

/// Immutable result of a macro calculation.
class MacroTargets {
  final int bmr;
  final int tdee;
  final int targetCalories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const MacroTargets({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

/// Pure nutrition math: Mifflin–St Jeor BMR, activity-scaled TDEE, goal
/// adjustment, a safe-minimum calorie floor, and the macro gram split.
///
/// Deliberately free of Firebase/UI dependencies so it can be unit-tested
/// directly. [MacroCalculatorViewModel] delegates to this.
class MacroMath {
  /// Maps a free-text activity level to its TDEE multiplier. Matches on
  /// substrings so values like "Moderately active" resolve correctly.
  /// Ordered most- to least-active so the strongest match wins.
  static double activityMultiplier(String activityLevel) {
    final a = activityLevel.toLowerCase();
    if (a.contains('extra')) return 1.9;
    if (a.contains('very')) return 1.725;
    if (a.contains('moderate')) return 1.55;
    if (a.contains('light')) return 1.375;
    return 1.2; // sedentary / unknown
  }

  static MacroTargets compute({
    required double weightKg,
    required double heightCm,
    required double age,
    required String sex,
    required String activityLevel,
    required String goal,
    required MacroSplit split,
  }) {
    final isMale = sex.toLowerCase() == 'male';
    final multiplier = activityMultiplier(activityLevel);

    // BMR (Mifflin–St Jeor).
    final rawBmr = isMale
        ? (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
        : (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;

    final rawTdee = rawBmr * multiplier;

    // Goal adjustment.
    final g = goal.toLowerCase();
    var rawTarget = rawTdee;
    if (g == 'cut') rawTarget = rawTdee - 500;
    if (g == 'bulk') rawTarget = rawTdee + 300;

    // Never recommend below a safe minimum.
    final minCalories = isMale ? 1500.0 : 1200.0;
    rawTarget = max(rawTarget, minCalories);

    // Macro grams: protein/carbs at 4 kcal/g, fat at 9 kcal/g.
    final (pPct, cPct, fPct) = split;
    return MacroTargets(
      bmr: rawBmr.round(),
      tdee: rawTdee.round(),
      targetCalories: rawTarget.round(),
      proteinG: ((rawTarget * pPct) / 4).round(),
      carbsG: ((rawTarget * cPct) / 4).round(),
      fatG: ((rawTarget * fPct) / 9).round(),
    );
  }
}
