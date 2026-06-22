// ── The exercise "type" drives which fields a set logs ──
// This is the core design decision: a bench press logs weight×reps, a plank
// logs duration, a run logs distance+duration. The logging UI reads these
// flags to render the right inputs instead of always showing everything.
enum ExerciseType {
  weightReps,          // barbell/dumbbell/machine lifts — weight × reps
  repsOnly,            // bodyweight — reps only (pull-ups, push-ups)
  weightedBodyweight,  // bodyweight + added load (weighted dips)
  duration,            // timed holds (plank, dead hang)
  distanceDuration,    // cardio (treadmill run, row)
}

extension ExerciseTypeX on ExerciseType {
  bool get needsWeight =>
      this == ExerciseType.weightReps ||
      this == ExerciseType.weightedBodyweight;

  bool get needsReps =>
      this == ExerciseType.weightReps ||
      this == ExerciseType.repsOnly ||
      this == ExerciseType.weightedBodyweight;

  bool get needsDistance => this == ExerciseType.distanceDuration;

  bool get needsDuration =>
      this == ExerciseType.duration || this == ExerciseType.distanceDuration;

  // Only weighted lifts contribute to volume and estimated 1RM.
  bool get countsVolume =>
      this == ExerciseType.weightReps ||
      this == ExerciseType.weightedBodyweight;

  bool get supports1RM => countsVolume;

  String get label {
    switch (this) {
      case ExerciseType.weightReps:         return 'Weight & Reps';
      case ExerciseType.repsOnly:           return 'Reps';
      case ExerciseType.weightedBodyweight: return 'Weighted Bodyweight';
      case ExerciseType.duration:           return 'Duration';
      case ExerciseType.distanceDuration:   return 'Distance & Duration';
    }
  }

  String get name => toString().split('.').last;
}

ExerciseType exerciseTypeFromName(String? name) {
  return ExerciseType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => ExerciseType.weightReps,
  );
}

// ── Filtering dimensions for the exercise picker ──
enum MuscleGroup { chest, back, legs, shoulders, arms, core, cardio, fullBody, other }

enum Equipment { barbell, dumbbell, machine, bodyweight, cardio, other }

extension MuscleGroupX on MuscleGroup {
  String get name => toString().split('.').last;
  String get label {
    switch (this) {
      case MuscleGroup.chest:     return 'Chest';
      case MuscleGroup.back:      return 'Back';
      case MuscleGroup.legs:      return 'Legs';
      case MuscleGroup.shoulders: return 'Shoulders';
      case MuscleGroup.arms:      return 'Arms';
      case MuscleGroup.core:      return 'Core';
      case MuscleGroup.cardio:    return 'Cardio';
      case MuscleGroup.fullBody:  return 'Full Body';
      case MuscleGroup.other:     return 'Other';
    }
  }
}

extension EquipmentX on Equipment {
  String get name => toString().split('.').last;
  String get label {
    switch (this) {
      case Equipment.barbell:    return 'Barbell';
      case Equipment.dumbbell:   return 'Dumbbell';
      case Equipment.machine:    return 'Machine';
      case Equipment.bodyweight: return 'Bodyweight';
      case Equipment.cardio:     return 'Cardio';
      case Equipment.other:      return 'Other';
    }
  }
}

MuscleGroup muscleGroupFromName(String? n) => MuscleGroup.values
    .firstWhere((m) => m.name == n, orElse: () => MuscleGroup.other);

Equipment equipmentFromName(String? n) => Equipment.values
    .firstWhere((e) => e.name == n, orElse: () => Equipment.other);

// ── An exercise definition (preset or user-created) ──
class Exercise {
  final String id;
  final String name;
  final ExerciseType type;
  final MuscleGroup muscleGroup;
  final Equipment equipment;
  final String? videoUrl;   // "how-to" demo (or a search query)
  final bool isCustom;
  final String? ownerUid;   // set when isCustom

  const Exercise({
    required this.id,
    required this.name,
    required this.type,
    required this.muscleGroup,
    required this.equipment,
    this.videoUrl,
    this.isCustom = false,
    this.ownerUid,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.name,
        'muscleGroup': muscleGroup.name,
        'equipment': equipment.name,
        'videoUrl': videoUrl,
        'isCustom': isCustom,
        'ownerUid': ownerUid,
      };

  factory Exercise.fromMap(String id, Map<String, dynamic> map) => Exercise(
        id: id,
        name: map['name'] ?? 'Exercise',
        type: exerciseTypeFromName(map['type']),
        muscleGroup: muscleGroupFromName(map['muscleGroup']),
        equipment: equipmentFromName(map['equipment']),
        videoUrl: map['videoUrl'],
        isCustom: map['isCustom'] ?? true,
        ownerUid: map['ownerUid'],
      );

  // Convenience for building a YouTube "how to" search when no explicit URL.
  String get howToSearchUrl =>
      videoUrl ??
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$name proper form')}';
}

// ── Built-in starter library (read-only). Custom exercises live in Firestore. ──
const List<Exercise> kPresetExercises = [
  // Chest
  Exercise(id: 'bench_press', name: 'Barbell Bench Press', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.chest, equipment: Equipment.barbell),
  Exercise(id: 'incline_db_press', name: 'Incline Dumbbell Press', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.chest, equipment: Equipment.dumbbell),
  Exercise(id: 'chest_fly_machine', name: 'Machine Chest Fly', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.chest, equipment: Equipment.machine),
  Exercise(id: 'push_up', name: 'Push-Up', type: ExerciseType.repsOnly, muscleGroup: MuscleGroup.chest, equipment: Equipment.bodyweight),
  // Back
  Exercise(id: 'deadlift', name: 'Deadlift', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.back, equipment: Equipment.barbell),
  Exercise(id: 'barbell_row', name: 'Barbell Row', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.back, equipment: Equipment.barbell),
  Exercise(id: 'lat_pulldown', name: 'Lat Pulldown', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.back, equipment: Equipment.machine),
  Exercise(id: 'pull_up', name: 'Pull-Up', type: ExerciseType.repsOnly, muscleGroup: MuscleGroup.back, equipment: Equipment.bodyweight),
  // Legs
  Exercise(id: 'back_squat', name: 'Barbell Back Squat', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.legs, equipment: Equipment.barbell),
  Exercise(id: 'leg_press', name: 'Leg Press', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.legs, equipment: Equipment.machine),
  Exercise(id: 'romanian_deadlift', name: 'Romanian Deadlift', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.legs, equipment: Equipment.barbell),
  Exercise(id: 'walking_lunge', name: 'Walking Lunge', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.legs, equipment: Equipment.dumbbell),
  // Shoulders
  Exercise(id: 'overhead_press', name: 'Overhead Press', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.shoulders, equipment: Equipment.barbell),
  Exercise(id: 'lateral_raise', name: 'Dumbbell Lateral Raise', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.shoulders, equipment: Equipment.dumbbell),
  // Arms
  Exercise(id: 'barbell_curl', name: 'Barbell Curl', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.arms, equipment: Equipment.barbell),
  Exercise(id: 'tricep_pushdown', name: 'Tricep Pushdown', type: ExerciseType.weightReps, muscleGroup: MuscleGroup.arms, equipment: Equipment.machine),
  Exercise(id: 'weighted_dip', name: 'Weighted Dip', type: ExerciseType.weightedBodyweight, muscleGroup: MuscleGroup.arms, equipment: Equipment.bodyweight),
  // Core
  Exercise(id: 'plank', name: 'Plank', type: ExerciseType.duration, muscleGroup: MuscleGroup.core, equipment: Equipment.bodyweight),
  Exercise(id: 'hanging_leg_raise', name: 'Hanging Leg Raise', type: ExerciseType.repsOnly, muscleGroup: MuscleGroup.core, equipment: Equipment.bodyweight),
  // Cardio
  Exercise(id: 'treadmill_run', name: 'Treadmill Run', type: ExerciseType.distanceDuration, muscleGroup: MuscleGroup.cardio, equipment: Equipment.cardio),
  Exercise(id: 'rowing', name: 'Rowing Machine', type: ExerciseType.distanceDuration, muscleGroup: MuscleGroup.cardio, equipment: Equipment.cardio),
  Exercise(id: 'cycling', name: 'Stationary Bike', type: ExerciseType.distanceDuration, muscleGroup: MuscleGroup.cardio, equipment: Equipment.cardio),
];
