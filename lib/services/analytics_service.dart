import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/analytics_range.dart';
import '../models/analytics_summary.dart';
import '../models/trend_point.dart';
import '../models/workout.dart';
import '../models/exercise.dart';
import 'workout_service.dart';
import 'exercise_library_service.dart';

/// The ONLY class permitted to read Firestore for Analytics (§2 layering).
///
/// It performs date-bounded, `.limit()`-ed reads, buckets the rows per the
/// active range, applies the data-hygiene rules (§10), and returns an
/// immutable [AnalyticsSummary]. No UI, no Provider.
///
/// NOTE on schema: the live app stores `daily_logs` with FLAT fields
/// (`consumed_calories`, `consumed_protein_g`, ...) rather than the nested
/// `consumed: { kcal }` shape sketched in the build brief. This service reads
/// the real schema and tolerates either. `steps_net` / `water_liters` are read
/// when present (the home screen persists them going forward); absent days are
/// treated as gaps, never zeros.
class AnalyticsService {
  AnalyticsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final WorkoutService _workoutService = WorkoutService();
  final ExerciseLibraryService _exerciseLibrary = ExerciseLibraryService();
  static final DateFormat _dayKey = DateFormat('yyyy-MM-dd');

  CollectionReference<Map<String, dynamic>> _logs(String uid) =>
      _db.collection('users').doc(uid).collection('daily_logs');

  Future<AnalyticsSummary> buildSummary({
    required String uid,
    required AnalyticsRange range,
    String weightUnit = 'kg',
  }) async {
    final now = DateTime.now();
    final windowStart = range.windowStart(now);
    final windowEnd = range.windowEnd(now);
    final prev = range.previousWindow(now);

    // ── Targets from the user profile doc ──
    final profileSnap = await _db.collection('users').doc(uid).get();
    final profile = profileSnap.data() ?? const {};
    final targets =
        (profile['nutritionTargets'] as Map<String, dynamic>?) ?? const {};
    final targetKcal = _asInt(targets['targetCalories']);
    final targetProteinG = _asInt(targets['proteinG']);

    // ── Daily logs spanning BOTH the current and previous window in one read
    //    (so we can compute period-over-period deltas cheaply). ──
    final logsSnap = await _logs(uid)
        .where('date',
            isGreaterThanOrEqualTo: _dayKey.format(prev.start))
        .where('date', isLessThan: _dayKey.format(windowEnd))
        .limit(220)
        .get();

    final byDay = <String, _DayLog>{};
    for (final doc in logsSnap.docs) {
      final log = _DayLog.fromMap(doc.id, doc.data());
      if (log != null && log.logged) byDay[log.dayKey] = log;
    }

    // ── Workouts: read via the existing WorkoutService (stores startedAt as
    //    epoch-millis, not Timestamp), then filter to the current window. ──
    final history = await _workoutService.getHistory(limit: 120);
    final workouts = history
        .where((w) =>
            !w.startedAt.isBefore(windowStart) && w.startedAt.isBefore(windowEnd))
        .toList();

    // ── Map exerciseId → muscle-group label from the exercise library
    //    (muscleGroup isn't stored on the workout doc). ──
    final muscleById = await _muscleLookup();

    return _aggregate(
      range: range,
      now: now,
      windowStart: windowStart,
      windowEnd: windowEnd,
      prev: prev,
      byDay: byDay,
      targetKcal: targetKcal,
      targetProteinG: targetProteinG,
      workouts: workouts,
      muscleById: muscleById,
      weightUnit: weightUnit,
    );
  }

  /// Builds an exerciseId → muscle-group-label lookup from presets + custom
  /// exercises. Falls back to an empty map if the library can't be read.
  Future<Map<String, String>> _muscleLookup() async {
    try {
      final library = await _exerciseLibrary.getAll();
      return {for (final e in library) e.id: e.muscleGroup.label};
    } catch (_) {
      return {for (final e in kPresetExercises) e.id: e.muscleGroup.label};
    }
  }

  // ───────────────────────── aggregation ─────────────────────────

  AnalyticsSummary _aggregate({
    required AnalyticsRange range,
    required DateTime now,
    required DateTime windowStart,
    required DateTime windowEnd,
    required AnalyticsBucketWindow prev,
    required Map<String, _DayLog> byDay,
    required int targetKcal,
    required int targetProteinG,
    required List<Workout> workouts,
    required Map<String, String> muscleById,
    required String weightUnit,
  }) {
    final buckets = range.buckets(now);

    // Current-window logged days (inside [windowStart, windowEnd)).
    final currentDays = byDay.values
        .where((d) => !d.date.isBefore(windowStart) && d.date.isBefore(windowEnd))
        .toList();
    final prevDays = byDay.values
        .where((d) => !d.date.isBefore(prev.start) && d.date.isBefore(prev.end))
        .toList();

    // ── Nutrition series (mean of logged days per bucket; gap if none) ──
    final caloriesSeries = <TrendPoint>[];
    final proteinSeries = <TrendPoint>[];
    final macroStackSeries = <MacroStackPoint>[];
    for (final b in buckets) {
      final inBucket =
          currentDays.where((d) => b.containsDay(d.date)).toList();
      if (inBucket.isEmpty) {
        caloriesSeries.add(TrendPoint(
            label: b.label, date: b.start, value: null, target: targetKcal.toDouble()));
        proteinSeries.add(TrendPoint(
            label: b.label,
            date: b.start,
            value: null,
            target: targetProteinG.toDouble()));
        macroStackSeries.add(MacroStackPoint(
            label: b.label,
            date: b.start,
            proteinG: 0,
            carbsG: 0,
            fatG: 0,
            logged: false));
      } else {
        final kcal = _mean(inBucket.map((d) => d.kcal.toDouble()));
        final protein = _mean(inBucket.map((d) => d.proteinG.toDouble()));
        final carbs = _mean(inBucket.map((d) => d.carbsG.toDouble()));
        final fat = _mean(inBucket.map((d) => d.fatG.toDouble()));
        caloriesSeries.add(TrendPoint(
            label: b.label,
            date: b.start,
            value: kcal,
            target: targetKcal.toDouble()));
        proteinSeries.add(TrendPoint(
            label: b.label,
            date: b.start,
            value: protein,
            target: targetProteinG.toDouble()));
        macroStackSeries.add(MacroStackPoint(
            label: b.label,
            date: b.start,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            logged: true));
      }
    }

    // ── Nutrition headline stats ──
    final avgKcalCur = _mean(currentDays.map((d) => d.kcal.toDouble()));
    final avgKcalPrev = _mean(prevDays.map((d) => d.kcal.toDouble()));
    final avgProtCur = _mean(currentDays.map((d) => d.proteinG.toDouble()));
    final avgProtPrev = _mean(prevDays.map((d) => d.proteinG.toDouble()));
    final avgCarbs = _mean(currentDays.map((d) => d.carbsG.toDouble()));
    final avgFat = _mean(currentDays.map((d) => d.fatG.toDouble()));

    final daysOnTarget = targetKcal <= 0
        ? 0
        : currentDays
            .where((d) =>
                (d.kcal - targetKcal).abs() <= targetKcal * 0.10)
            .length;

    final loggingStreak = _loggingStreak(byDay, now);

    // ── Activity series (steps + water; only where persisted) ──
    final stepsSeries = <TrendPoint>[];
    final waterSeries = <TrendPoint>[];
    for (final b in buckets) {
      final inBucket = currentDays
          .where((d) => b.containsDay(d.date))
          .toList();
      final stepDays = inBucket.where((d) => d.steps != null);
      final waterDays = inBucket.where((d) => d.water != null);
      stepsSeries.add(TrendPoint(
        label: b.label,
        date: b.start,
        value: stepDays.isEmpty
            ? null
            : _mean(stepDays.map((d) => d.steps!.toDouble())),
      ));
      waterSeries.add(TrendPoint(
        label: b.label,
        date: b.start,
        value: waterDays.isEmpty
            ? null
            : _mean(waterDays.map((d) => d.water!)),
      ));
    }
    final avgStepsCur = _mean(
        currentDays.where((d) => d.steps != null).map((d) => d.steps!.toDouble()));
    final avgStepsPrev = _mean(
        prevDays.where((d) => d.steps != null).map((d) => d.steps!.toDouble()));
    final avgWaterCur =
        _mean(currentDays.where((d) => d.water != null).map((d) => d.water!));
    final avgWaterPrev =
        _mean(prevDays.where((d) => d.water != null).map((d) => d.water!));

    // ── Workout aggregation (computed in-memory from Workout history) ──
    final volumeSeries = <TrendPoint>[];
    for (final b in buckets) {
      final inBucket = workouts
          .where((w) => b.containsDay(_midnight(w.startedAt)))
          .toList();
      volumeSeries.add(TrendPoint(
        label: b.label,
        date: b.start,
        value: inBucket.isEmpty
            ? null
            : inBucket.fold<double>(0, (s, w) => s + w.totalVolumeKg),
      ));
    }
    final totalVolume =
        workouts.fold<double>(0, (s, w) => s + w.totalVolumeKg);
    final workoutDays = workouts.map((w) => _midnight(w.startedAt)).toSet();
    final workoutStreak = _dayStreak(workoutDays, now);

    // Single pass over every working set: sets count, muscle volume,
    // per-exercise daily best e1RM (series) and overall best (PR).
    var totalSets = 0;
    final muscleVolume = <String, double>{};
    final exerciseNames = <String, String>{};
    final e1rmDayBest = <String, Map<DateTime, double>>{};
    final prBest = <String, ({double value, DateTime date})>{};

    for (final w in workouts) {
      final day = _midnight(w.startedAt);
      for (final ex in w.exercises) {
        exerciseNames[ex.exerciseId] = ex.name;
        final muscle = muscleById[ex.exerciseId] ?? 'Other';
        double bestE1rmThisDay = 0;
        for (final s in ex.sets) {
          if (s.type == SetType.warmup) continue;
          totalSets++;
          muscleVolume[muscle] = (muscleVolume[muscle] ?? 0) + s.volume();
          final e1rm = s.estimated1RM();
          if (e1rm != null && e1rm > bestE1rmThisDay) bestE1rmThisDay = e1rm;
        }
        if (bestE1rmThisDay > 0) {
          final dayMap = e1rmDayBest.putIfAbsent(ex.exerciseId, () => {});
          if (bestE1rmThisDay > (dayMap[day] ?? 0)) {
            dayMap[day] = bestE1rmThisDay;
          }
          final pr = prBest[ex.exerciseId];
          if (pr == null || bestE1rmThisDay > pr.value) {
            prBest[ex.exerciseId] = (value: bestE1rmThisDay, date: day);
          }
        }
      }
    }

    // Build sorted e1RM series per exercise.
    final e1rmByExercise = <String, List<TrendPoint>>{};
    e1rmDayBest.forEach((id, dayMap) {
      final points = dayMap.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      e1rmByExercise[id] = points
          .map((e) => TrendPoint(
                label: DateFormat('d MMM').format(e.key),
                date: e.key,
                value: e.value,
              ))
          .toList();
    });

    // PR feed — best e1RM per exercise this period, dated to when it landed.
    final prs = <PrRecord>[];
    prBest.forEach((id, best) {
      prs.add(PrRecord(
        exerciseName: exerciseNames[id] ?? id,
        date: best.date,
        metric: 'Best e1RM',
        value: best.value,
        unit: weightUnit,
      ));
    });
    prs.sort((a, b) => b.date.compareTo(a.date));

    // ── Heatmaps ──
    final nutritionHeat = _buildHeat(
      windowStart: windowStart,
      windowEnd: windowEnd,
      isOn: (day) {
        final log = byDay[_dayKey.format(day)];
        return log == null
            ? null
            : (target: targetKcal > 0 &&
                (log.kcal - targetKcal).abs() <= targetKcal * 0.10);
      },
    );
    final workoutHeat = _buildHeat(
      windowStart: windowStart,
      windowEnd: windowEnd,
      isOn: (day) =>
          workoutDays.contains(day) ? (target: true) : null,
    );

    return AnalyticsSummary(
      range: range,
      windowStart: windowStart,
      windowEnd: windowEnd,
      totalDays: range.windowDays,
      daysLogged: currentDays.length,
      caloriesSeries: caloriesSeries,
      proteinSeries: proteinSeries,
      macroStackSeries: macroStackSeries,
      nutritionHeat: nutritionHeat,
      avgCalories: StatDelta(avgKcalCur, _pctDelta(avgKcalCur, avgKcalPrev)),
      avgProtein: StatDelta(avgProtCur, _pctDelta(avgProtCur, avgProtPrev)),
      avgCarbs: avgCarbs,
      avgFat: avgFat,
      daysOnTarget: daysOnTarget,
      loggingStreak: loggingStreak,
      macroAvgProteinG: avgProtCur,
      macroAvgCarbsG: avgCarbs,
      macroAvgFatG: avgFat,
      targetKcal: targetKcal,
      targetProteinG: targetProteinG,
      stepsSeries: stepsSeries,
      waterSeries: waterSeries,
      avgSteps: StatDelta(avgStepsCur, _pctDelta(avgStepsCur, avgStepsPrev)),
      avgWater: StatDelta(avgWaterCur, _pctDelta(avgWaterCur, avgWaterPrev)),
      volumeSeries: volumeSeries,
      totalVolume: StatDelta(totalVolume),
      totalSessions: workouts.length,
      totalSets: totalSets,
      workoutStreak: workoutStreak,
      prs: prs,
      e1rmByExercise: e1rmByExercise,
      exerciseNames: exerciseNames,
      muscleVolume: muscleVolume,
      workoutHeat: workoutHeat,
      nutritionTakeaway: _nutritionTakeaway(
          daysOnTarget, currentDays.length, avgProtCur, targetProteinG),
      workoutTakeaway: _workoutTakeaway(workouts.length, prs.length),
      overviewTakeaway: _overviewTakeaway(
          workouts.length, avgProtCur, targetProteinG),
    );
  }

  // ───────────────────────── helpers ─────────────────────────

  List<HeatCell> _buildHeat({
    required DateTime windowStart,
    required DateTime windowEnd,
    required ({bool target})? Function(DateTime day) isOn,
  }) {
    final cells = <HeatCell>[];
    var cursor = windowStart;
    while (cursor.isBefore(windowEnd)) {
      final state = isOn(cursor);
      cells.add(HeatCell(
        date: cursor,
        logged: state != null,
        goalHit: state?.target ?? false,
        intensity: state == null ? 0 : (state.target ? 1.0 : 0.5),
      ));
      cursor = cursor.add(const Duration(days: 1));
    }
    return cells;
  }

  /// Consecutive logged days ending today (or yesterday if today not logged).
  int _loggingStreak(Map<String, _DayLog> byDay, DateTime now) {
    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    if (!byDay.containsKey(_dayKey.format(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1)); // grace for today
    }
    while (byDay.containsKey(_dayKey.format(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _dayStreak(Set<DateTime> days, DateTime now) {
    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  static double _mean(Iterable<double> xs) {
    var sum = 0.0;
    var n = 0;
    for (final x in xs) {
      sum += x;
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  static double? _pctDelta(double current, double previous) {
    if (previous <= 0) return null;
    return (current - previous) / previous * 100.0;
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  // ───────────────────────── takeaways ─────────────────────────

  String _nutritionTakeaway(
      int onTarget, int logged, double avgProtein, int targetProtein) {
    if (logged < 2) return 'Log a few days to unlock your trends.';
    if (targetProtein > 0 && avgProtein < targetProtein * 0.85) {
      return 'Protein is running below target — aim a little higher.';
    }
    if (onTarget >= logged * 0.7) {
      return 'Great consistency — most days landed on your calorie target.';
    }
    return 'You hit your calorie target on $onTarget of $logged logged days.';
  }

  String _workoutTakeaway(int sessions, int prs) {
    if (sessions == 0) return 'Log a few workouts to unlock your trends.';
    final prPart = prs > 0 ? ' · $prs PR${prs == 1 ? '' : 's'}' : '';
    return '$sessions session${sessions == 1 ? '' : 's'} this period$prPart.';
  }

  String _overviewTakeaway(int sessions, double avgProtein, int targetProtein) {
    if (sessions == 0) return 'Train and log meals to see how they line up.';
    if (targetProtein > 0 && avgProtein >= targetProtein * 0.9) {
      return 'Solid training volume backed by on-point protein intake.';
    }
    return 'Training is on — nudge protein up to match the effort.';
  }
}

// ───────────────────────── internal row models ─────────────────────────

class _DayLog {
  final String dayKey;
  final DateTime date;
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int? steps;
  final double? water;

  _DayLog({
    required this.dayKey,
    required this.date,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.steps,
    required this.water,
  });

  /// A day counts as logged only if it has real calories — 0-kcal artefacts
  /// from failed scans are treated as not-logged gaps (§10).
  bool get logged => kcal > 0;

  static _DayLog? fromMap(String id, Map<String, dynamic> m) {
    final dayKey = (m['date'] as String?) ?? id;
    final date = DateTime.tryParse(dayKey);
    if (date == null) return null;

    // Tolerate both the flat live schema and the nested brief schema.
    final consumed = m['consumed'] as Map<String, dynamic>?;
    int n(String flat, String nested) =>
        AnalyticsService._asInt(m[flat] ?? (consumed?[nested]));

    final steps = m['steps_net'] ?? (m['steps'] as Map?)?['net'];
    final water = m['water_liters'] ?? m['water'];

    return _DayLog(
      dayKey: dayKey,
      date: DateTime(date.year, date.month, date.day),
      kcal: n('consumed_calories', 'kcal'),
      proteinG: n('consumed_protein_g', 'proteinG'),
      carbsG: n('consumed_carbs_g', 'carbsG'),
      fatG: n('consumed_fat_g', 'fatG'),
      steps: steps == null ? null : AnalyticsService._asInt(steps),
      water: water == null ? null : (water as num).toDouble(),
    );
  }
}
