import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Create full profile including nutrition targets ──
  Future<void> createUserProfile(UserProfile profile) async {
    await _db
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap());
  }

  // ── Update ONLY the nutrition targets (called after macro screen) ──
  Future<void> updateNutritionTargets(
      String uid,
      NutritionTargets targets,
      ) async {
    await _db.collection('users').doc(uid).update({
      'nutritionTargets': targets.toMap(),
    });
  }

  // ── Fetch full profile ──
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(uid, doc.data()!);
  }
}