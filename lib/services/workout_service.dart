import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/workout.dart';

/// Best historical numbers for one exercise, used for PR detection.
class ExerciseBest {
  double maxWeightKg;
  double maxEstimated1RM;
  double maxSetVolume;

  ExerciseBest({
    this.maxWeightKg = 0,
    this.maxEstimated1RM = 0,
    this.maxSetVolume = 0,
  });
}

/// Reads/writes finished workouts under users/{uid}/workouts and derives the
/// "previous performance" and personal-record data the logging screen needs.
class WorkoutService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    return _db.collection('users').doc(uid).collection('workouts');
  }

  Future<void> saveWorkout(Workout workout) async {
    await _col().add(workout.toMap());
  }

  Future<void> deleteWorkout(String id) async {
    await _col().doc(id).delete();
  }

  /// Most recent finished workouts, newest first.
  Future<List<Workout>> getHistory({int limit = 50}) async {
    try {
      final snap = await _col()
          .orderBy('finishedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => Workout.fromMap(d.id, d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Stream<List<Workout>> historyStream({int limit = 50}) {
    return _col()
        .orderBy('finishedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Workout.fromMap(d.id, d.data())).toList());
  }

  // ─── Derived data for the active session ───────────────────────────

  /// The sets performed for each exercise in the *most recent* workout that
  /// contained it — this powers the "previous: 80 kg × 8" column.
  Map<String, List<WorkoutSet>> previousByExercise(List<Workout> history) {
    final result = <String, List<WorkoutSet>>{};
    // history is newest-first, so the first occurrence wins.
    for (final w in history) {
      for (final ex in w.exercises) {
        result.putIfAbsent(
          ex.exerciseId,
          () => ex.sets.where((s) => s.type != SetType.warmup).toList(),
        );
      }
    }
    return result;
  }

  /// Best historical weight / estimated-1RM / set-volume per exercise, used to
  /// decide whether a freshly logged set is a PR.
  Map<String, ExerciseBest> bestsByExercise(List<Workout> history) {
    final result = <String, ExerciseBest>{};
    for (final w in history) {
      for (final ex in w.exercises) {
        final best = result.putIfAbsent(ex.exerciseId, () => ExerciseBest());
        for (final s in ex.sets) {
          if (s.type == SetType.warmup) continue;
          if (s.weightKg != null && s.weightKg! > best.maxWeightKg) {
            best.maxWeightKg = s.weightKg!;
          }
          final e1rm = s.estimated1RM();
          if (e1rm != null && e1rm > best.maxEstimated1RM) {
            best.maxEstimated1RM = e1rm;
          }
          final vol = s.volume();
          if (vol > best.maxSetVolume) best.maxSetVolume = vol;
        }
      }
    }
    return result;
  }
}
