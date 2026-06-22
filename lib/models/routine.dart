import 'exercise.dart';

/// One planned exercise inside a routine, with goal-driven targets.
class RoutineExercise {
  final String exerciseId;
  final String name;
  final ExerciseType type;
  final MuscleGroup muscleGroup;
  final int targetSets;
  final int? targetReps;         // for rep-based work
  final int? targetDurationSec;  // for timed / cardio work

  const RoutineExercise({
    required this.exerciseId,
    required this.name,
    required this.type,
    required this.muscleGroup,
    required this.targetSets,
    this.targetReps,
    this.targetDurationSec,
  });

  String get targetLabel {
    if (type.needsReps) return '$targetSets × ${targetReps ?? '-'}';
    if (type == ExerciseType.distanceDuration && targetDurationSec != null) {
      return '${(targetDurationSec! / 60).round()} min';
    }
    if (type.needsDuration && targetDurationSec != null) {
      return '$targetSets × ${targetDurationSec}s';
    }
    return '$targetSets sets';
  }

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'name': name,
        'type': type.name,
        'muscleGroup': muscleGroup.name,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'targetDurationSec': targetDurationSec,
      };

  factory RoutineExercise.fromMap(Map<String, dynamic> m) => RoutineExercise(
        exerciseId: m['exerciseId'] ?? '',
        name: m['name'] ?? 'Exercise',
        type: exerciseTypeFromName(m['type']),
        muscleGroup: muscleGroupFromName(m['muscleGroup']),
        targetSets: (m['targetSets'] as num?)?.toInt() ?? 3,
        targetReps: (m['targetReps'] as num?)?.toInt(),
        targetDurationSec: (m['targetDurationSec'] as num?)?.toInt(),
      );
}

/// A reusable, ordered list of exercises — a template ("Push Day") you can
/// start a session from. Recommendations are generated as in-memory Routines.
class Routine {
  final String? id;
  final String name;
  final String goal;
  final int daysPerWeek;
  final String? focusSummary;   // e.g. "Chest · Shoulders · Triceps"
  final List<RoutineExercise> exercises;

  const Routine({
    this.id,
    required this.name,
    required this.goal,
    required this.daysPerWeek,
    this.focusSummary,
    required this.exercises,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'goal': goal,
        'daysPerWeek': daysPerWeek,
        'focusSummary': focusSummary,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  factory Routine.fromMap(String? id, Map<String, dynamic> m) => Routine(
        id: id,
        name: m['name'] ?? 'Routine',
        goal: m['goal'] ?? 'maintain',
        daysPerWeek: (m['daysPerWeek'] as num?)?.toInt() ?? 3,
        focusSummary: m['focusSummary'],
        exercises: ((m['exercises'] as List?) ?? [])
            .map((e) => RoutineExercise.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
