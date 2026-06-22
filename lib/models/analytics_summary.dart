import 'analytics_range.dart';
import 'trend_point.dart';

/// A headline stat with an optional period-over-period delta.
///
/// [delta] is the signed percentage change vs the previous equivalent
/// period (null when there's no comparable prior data).
class StatDelta {
  final double current;
  final double? delta; // signed %, e.g. +12.5 or -4.0

  const StatDelta(this.current, [this.delta]);

  bool get hasDelta => delta != null && delta!.isFinite;
  bool get isPositive => (delta ?? 0) >= 0;
}

/// Immutable, ready-to-plot aggregate for a single range.
///
/// One summary carries all three domains (overview/nutrition/workout) so the
/// ViewModel can cache exactly one object per range. The service computes
/// everything here once; widgets only read.
class AnalyticsSummary {
  final AnalyticsRange range;
  final DateTime windowStart;
  final DateTime windowEnd;

  // ── Coverage ──
  final int totalDays;
  final int daysLogged;

  // ── Nutrition series ──
  final List<TrendPoint> caloriesSeries; // value vs targetKcal
  final List<TrendPoint> proteinSeries; // value vs targetProtein
  final List<MacroStackPoint> macroStackSeries; // P/C/F grams per bucket
  final List<HeatCell> nutritionHeat; // calendar consistency

  // ── Nutrition headline stats ──
  final StatDelta avgCalories;
  final StatDelta avgProtein;
  final double avgCarbs;
  final double avgFat;
  final int daysOnTarget; // calories within ±10% of target
  final int loggingStreak; // consecutive logged days ending today

  // Macro averages (grams) for the donut.
  final double macroAvgProteinG;
  final double macroAvgCarbsG;
  final double macroAvgFatG;

  // ── Targets (for chart goal lines / labels) ──
  final int targetKcal;
  final int targetProteinG;

  // ── Activity (steps + water) ──
  final List<TrendPoint> stepsSeries;
  final List<TrendPoint> waterSeries;
  final StatDelta avgSteps;
  final StatDelta avgWater;

  // ── Workout ──
  final List<TrendPoint> volumeSeries; // training volume per bucket
  final StatDelta totalVolume;
  final int totalSessions;
  final int totalSets;
  final int workoutStreak;
  final List<PrRecord> prs;
  final Map<String, List<TrendPoint>> e1rmByExercise; // exerciseId -> series
  final Map<String, String> exerciseNames; // exerciseId -> display name
  final Map<String, double> muscleVolume; // muscleGroup -> volume
  final List<HeatCell> workoutHeat; // workout-day frequency

  // ── Body weight ──
  final List<TrendPoint> weightSeries; // logged weights within the window
  final double? weightLatestKg; // most recent weight in the window
  final double? weightDeltaKg; // latest − earliest in the window

  // ── Plain-English takeaways (§10 rules baked in service) ──
  final String nutritionTakeaway;
  final String workoutTakeaway;
  final String overviewTakeaway;

  const AnalyticsSummary({
    required this.range,
    required this.windowStart,
    required this.windowEnd,
    required this.totalDays,
    required this.daysLogged,
    required this.caloriesSeries,
    required this.proteinSeries,
    required this.macroStackSeries,
    required this.nutritionHeat,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFat,
    required this.daysOnTarget,
    required this.loggingStreak,
    required this.macroAvgProteinG,
    required this.macroAvgCarbsG,
    required this.macroAvgFatG,
    required this.targetKcal,
    required this.targetProteinG,
    required this.stepsSeries,
    required this.waterSeries,
    required this.avgSteps,
    required this.avgWater,
    required this.volumeSeries,
    required this.totalVolume,
    required this.totalSessions,
    required this.totalSets,
    required this.workoutStreak,
    required this.prs,
    required this.e1rmByExercise,
    required this.exerciseNames,
    required this.muscleVolume,
    required this.workoutHeat,
    required this.weightSeries,
    required this.weightLatestKg,
    required this.weightDeltaKg,
    required this.nutritionTakeaway,
    required this.workoutTakeaway,
    required this.overviewTakeaway,
  });

  /// True when there's too little nutrition data to draw trends (§9 empty).
  bool get nutritionEmpty => daysLogged < 2;

  /// True when no workouts exist in the window (§9 empty).
  bool get workoutEmpty => totalSessions == 0;

  bool get hasActivity =>
      stepsSeries.any((p) => p.hasValue) || waterSeries.any((p) => p.hasValue);

  bool get hasWeight => weightSeries.any((p) => p.hasValue);
}
