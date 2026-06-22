import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/exercise.dart';

/// Provides the combined exercise library: built-in presets plus the user's
/// own custom exercises (stored under users/{uid}/custom_exercises).
class ExerciseLibraryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _customCol() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    return _db.collection('users').doc(uid).collection('custom_exercises');
  }

  /// Presets first, then the user's custom exercises.
  Future<List<Exercise>> getAll() async {
    final list = <Exercise>[...kPresetExercises];
    try {
      final snap = await _customCol().get();
      list.addAll(snap.docs.map((d) => Exercise.fromMap(d.id, d.data())));
    } catch (_) {
      // If custom fetch fails (offline / rules), still return presets.
    }
    return list;
  }

  Future<Exercise> createCustom({
    required String name,
    required ExerciseType type,
    required MuscleGroup muscleGroup,
    required Equipment equipment,
    String? videoUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final exercise = Exercise(
      id: 'tmp',
      name: name,
      type: type,
      muscleGroup: muscleGroup,
      equipment: equipment,
      videoUrl: videoUrl,
      isCustom: true,
      ownerUid: uid,
    );
    final ref = await _customCol().add(exercise.toMap());
    return Exercise.fromMap(ref.id, exercise.toMap());
  }

  Future<void> deleteCustom(String exerciseId) async {
    await _customCol().doc(exerciseId).delete();
  }
}
