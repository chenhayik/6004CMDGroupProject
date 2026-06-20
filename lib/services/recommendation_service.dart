import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/workout.dart';

/// Rule-based, history-aware workout recommender.
///
/// Maps the user's goal + chosen training frequency to a training split, then
/// recommends the *next* session by rotating through that split (so consecutive
/// recommendations train different muscles — basic recovery awareness). The
/// active-session screen handles progressive overload by pre-filling each set
/// from the user's previous performance.
class RecommendationService {
  // ── Default days/week from onboarding profile ──
  int defaultDaysPerWeek({required String activityLevel, required String goal}) {
    final a = activityLevel.toLowerCase();
    int base;
    if (a.contains('extra') || a.contains('very')) {
      base = 5;
    } else if (a.contains('moderate')) {
      base = 4;
    } else {
      base = 3; // sedentary / light
    }
    // Bulking benefits from a bit more frequency/volume.
    if (goal.toLowerCase() == 'bulk' && base < 4) base = 4;
    return base.clamp(3, 5);
  }

  // ── Split rotation by frequency ──
  List<String> _rotation(int daysPerWeek) {
    if (daysPerWeek <= 3) return ['fullBodyA', 'fullBodyB'];
    if (daysPerWeek == 4) return ['upper', 'lower'];
    return ['push', 'pull', 'legs'];
  }

  // ── Curated preset IDs per day (compound-first, sensible pairings) ──
  static const Map<String, List<String>> _dayExercises = {
    'push': ['bench_press', 'incline_db_press', 'overhead_press', 'lateral_raise', 'tricep_pushdown'],
    'pull': ['deadlift', 'barbell_row', 'lat_pulldown', 'pull_up', 'barbell_curl'],
    'legs': ['back_squat', 'romanian_deadlift', 'leg_press', 'walking_lunge', 'plank'],
    'upper': ['bench_press', 'barbell_row', 'overhead_press', 'lat_pulldown', 'tricep_pushdown', 'barbell_curl'],
    'lower': ['back_squat', 'romanian_deadlift', 'leg_press', 'walking_lunge', 'plank'],
    'fullBodyA': ['back_squat', 'bench_press', 'barbell_row', 'overhead_press', 'plank'],
    'fullBodyB': ['deadlift', 'incline_db_press', 'lat_pulldown', 'lateral_raise', 'hanging_leg_raise'],
  };

  static const Map<String, String> _dayTitle = {
    'push': 'Push Day',
    'pull': 'Pull Day',
    'legs': 'Leg Day',
    'upper': 'Upper Body',
    'lower': 'Lower Body',
    'fullBodyA': 'Full Body A',
    'fullBodyB': 'Full Body B',
  };

  // Cardio finishers rotated for variety (used on cut goals).
  static const List<String> _cardioFinishers = ['treadmill_run', 'rowing', 'cycling'];

  Exercise _preset(String id) =>
      kPresetExercises.firstWhere((e) => e.id == id);

  // ── Goal → set/rep scheme ──
  (int sets, int reps) _scheme(String goal) {
    switch (goal.toLowerCase()) {
      case 'cut':
        return (3, 14); // higher reps, preserve muscle in a deficit
      case 'bulk':
        return (4, 8); // more volume + lower reps for hypertrophy/strength
      default:
        return (3, 10); // maintain
    }
  }

  RoutineExercise _routineExercise(String id, int sets, int reps) {
    final e = _preset(id);
    return RoutineExercise(
      exerciseId: e.id,
      name: e.name,
      type: e.type,
      muscleGroup: e.muscleGroup,
      targetSets: e.type == ExerciseType.distanceDuration ? 1 : sets,
      targetReps: e.type.needsReps ? reps : null,
      targetDurationSec: e.type.needsDuration
          ? (e.muscleGroup == MuscleGroup.cardio ? 600 : 45)
          : null,
    );
  }

  /// Recommends the next session for [goal] at [daysPerWeek], using [history]
  /// to advance through the split rotation.
  Routine recommend({
    required String goal,
    required String activityLevel,
    required int daysPerWeek,
    required List<Workout> history,
  }) {
    final rotation = _rotation(daysPerWeek);
    // Advance through the split as the user logs workouts → recovery-aware
    // in the sense that consecutive recommendations differ.
    final dayIndex = history.length % rotation.length;
    final dayKey = rotation[dayIndex];

    final (sets, reps) = _scheme(goal);

    final exercises = <RoutineExercise>[
      for (final id in _dayExercises[dayKey]!) _routineExercise(id, sets, reps),
    ];

    // Cardio finisher when cutting (rotated for variety).
    if (goal.toLowerCase() == 'cut') {
      final cardioId =
          _cardioFinishers[history.length % _cardioFinishers.length];
      exercises.add(_routineExercise(cardioId, 1, 0));
    }

    final focus = _focusSummary(exercises);

    return Routine(
      name: _dayTitle[dayKey] ?? 'Workout',
      goal: goal,
      daysPerWeek: daysPerWeek,
      focusSummary: focus,
      exercises: exercises,
    );
  }

  String _focusSummary(List<RoutineExercise> exercises) {
    final seen = <MuscleGroup>{};
    final ordered = <MuscleGroup>[];
    for (final e in exercises) {
      if (seen.add(e.muscleGroup)) ordered.add(e.muscleGroup);
    }
    return ordered.take(4).map((g) => g.label).join(' · ');
  }
}
