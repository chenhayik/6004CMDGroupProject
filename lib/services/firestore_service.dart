import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Save profile to users/{uid}
  Future<void> createUserProfile(UserProfile profile) async {
    await _db
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap());
  }

  // Check if profile exists
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return UserProfile(
      uid: uid,
      age: data['age'],
      biologicalSex: data['biologicalSex'],
      height: (data['height'] as num).toDouble(),
      weight: (data['weight'] as num).toDouble(),
      activityLevel: data['activityLevel'],
      goal: data['goal'],
    );
  }
}