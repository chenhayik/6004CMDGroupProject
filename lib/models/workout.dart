import 'exercise.dart';

// ── A set's role — warm-ups don't count toward volume or PRs ──
enum SetType { warmup, normal, drop, failure }

extension SetTypeX on SetType {
  String get name => toString().split('.').last;
  String get shortLabel {
    switch (this) {
      case SetType.warmup:  return 'W';
      case SetType.normal:  return '';   // shown as the set number
      case SetType.drop:    return 'D';
      case SetType.failure: return 'F';
    }
  }
}

SetType setTypeFromName(String? n) =>
    SetType.values.firstWhere((s) => s.name == n, orElse: () => SetType.normal);

/// A single logged set. Which fields are meaningful depends on the parent
/// exercise's [ExerciseType]; unused fields stay null.
class WorkoutSet {
  SetType type;
  double? weightKg;
  int? reps;
  double? distanceM;
  int? durationSec;
  double? rpe;        // optional rate of perceived exertion (1–10)
  bool completed;
  bool isPR;          // set when this set beat a personal record

  WorkoutSet({
    this.type = SetType.normal,
    this.weightKg,
    this.reps,
    this.distanceM,
    this.durationSec,
    this.rpe,
    this.completed = false,
    this.isPR = false,
  });

  bool get countsForStats => type != SetType.warmup && completed;

  // Volume only makes sense for weighted work.
  double volume() =>
      (weightKg != null && reps != null) ? weightKg! * reps! : 0;

  // Epley estimated 1RM: weight × (1 + reps/30).
  double? estimated1RM() {
    if (weightKg == null || reps == null || reps! <= 0) return null;
    return weightKg! * (1 + reps! / 30.0);
  }

  WorkoutSet copy() => WorkoutSet(
        type: type,
        weightKg: weightKg,
        reps: reps,
        distanceM: distanceM,
        durationSec: durationSec,
        rpe: rpe,
        completed: false, // a copy is a fresh, uncompleted set
        isPR: false,
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'weightKg': weightKg,
        'reps': reps,
        'distanceM': distanceM,
        'durationSec': durationSec,
        'rpe': rpe,
        'completed': completed,
        'isPR': isPR,
      };

  factory WorkoutSet.fromMap(Map<String, dynamic> m) => WorkoutSet(
        type: setTypeFromName(m['type']),
        weightKg: (m['weightKg'] as num?)?.toDouble(),
        reps: (m['reps'] as num?)?.toInt(),
        distanceM: (m['distanceM'] as num?)?.toDouble(),
        durationSec: (m['durationSec'] as num?)?.toInt(),
        rpe: (m['rpe'] as num?)?.toDouble(),
        completed: m['completed'] ?? false,
        isPR: m['isPR'] ?? false,
      );
}

/// One exercise within a workout, carrying its ordered sets.
class WorkoutExercise {
  final String exerciseId;
  final String name;
  final ExerciseType type;
  String? notes;
  List<WorkoutSet> sets;

  WorkoutExercise({
    required this.exerciseId,
    required this.name,
    required this.type,
    this.notes,
    List<WorkoutSet>? sets,
  }) : sets = sets ?? [];

  double totalVolume() =>
      sets.where((s) => s.countsForStats).fold(0.0, (a, s) => a + s.volume());

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'name': name,
        'type': type.name,
        'notes': notes,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  factory WorkoutExercise.fromMap(Map<String, dynamic> m) => WorkoutExercise(
        exerciseId: m['exerciseId'] ?? '',
        name: m['name'] ?? 'Exercise',
        type: exerciseTypeFromName(m['type']),
        notes: m['notes'],
        sets: ((m['sets'] as List?) ?? [])
            .map((e) => WorkoutSet.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// A workout session — one actual performance on a given day.
/// Dates are stored as epoch millis so the same map works for both Firestore
/// and local (shared_preferences) resume persistence.
class Workout {
  String? id;
  String name;
  DateTime startedAt;
  DateTime? finishedAt;
  String? fromRoutineId;
  List<WorkoutExercise> exercises;

  Workout({
    this.id,
    required this.name,
    required this.startedAt,
    this.finishedAt,
    this.fromRoutineId,
    List<WorkoutExercise>? exercises,
  }) : exercises = exercises ?? [];

  double get totalVolumeKg =>
      exercises.fold(0.0, (a, e) => a + e.totalVolume());

  int get completedSetCount => exercises
      .expand((e) => e.sets)
      .where((s) => s.countsForStats)
      .length;

  int get durationSec => finishedAt == null
      ? DateTime.now().difference(startedAt).inSeconds
      : finishedAt!.difference(startedAt).inSeconds;

  Map<String, dynamic> toMap() => {
        'name': name,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'finishedAt': finishedAt?.millisecondsSinceEpoch,
        'fromRoutineId': fromRoutineId,
        'totalVolumeKg': totalVolumeKg,
        'durationSec': durationSec,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  factory Workout.fromMap(String? id, Map<String, dynamic> m) => Workout(
        id: id,
        name: m['name'] ?? 'Workout',
        startedAt:
            DateTime.fromMillisecondsSinceEpoch((m['startedAt'] as num?)?.toInt() ?? 0),
        finishedAt: m['finishedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((m['finishedAt'] as num).toInt()),
        fromRoutineId: m['fromRoutineId'],
        exercises: ((m['exercises'] as List?) ?? [])
            .map((e) => WorkoutExercise.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
