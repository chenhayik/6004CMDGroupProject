import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/coach_profile.dart';

/// Reads/writes the `coaches` collection. One top-level doc per trainer, keyed
/// by the trainer's auth uid — a user may only write their own (enforced in
/// firestore.rules) but any signed-in user may browse all of them.
class CoachService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('coaches');

  /// All registered coaches, newest-updated first. A one-shot read (the
  /// directory doesn't need realtime) keeps Firestore reads minimal.
  Future<List<CoachProfile>> getCoaches() async {
    final snap = await _col.orderBy('updatedAt', descending: true).limit(100).get();
    return snap.docs
        .map((d) => CoachProfile.fromMap(d.id, d.data()))
        .toList();
  }

  /// The signed-in user's own coach profile, or null if they haven't registered.
  Future<CoachProfile?> getMyCoach(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return CoachProfile.fromMap(doc.id, doc.data()!);
  }

  /// Create or update the caller's own coach profile.
  Future<void> upsert(CoachProfile coach) async {
    await _col.doc(coach.uid).set(coach.toMap(), SetOptions(merge: true));
  }

  Future<void> delete(String uid) async {
    await _col.doc(uid).delete();
  }
}
