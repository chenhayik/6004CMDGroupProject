import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/weight_entry.dart';

/// Reads/writes body-weight history under users/{uid}/weight_logs and keeps the
/// profile's current `weight` field in sync with the latest entry.
///
/// Weight history and nutrition targets are intentionally decoupled — logging a
/// weight never recomputes targets (the user does that via the goal/calculator
/// flow). This service only updates the profile's current weight value.
class WeightService {
  WeightService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  static final DateFormat _dayKey = DateFormat('yyyy-MM-dd');

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('weight_logs');

  /// Log today's weight (kg) and update the profile's current weight.
  Future<void> logWeight(String uid, double kg) async {
    final today = _dayKey.format(DateTime.now());
    await _col(uid).doc(today).set(
      {
        'date': today,
        'weight_kg': kg,
        'logged_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await _db.collection('users').doc(uid).update({'weight': kg});
  }

  /// Recent entries, oldest → newest (ready to plot).
  Future<List<WeightEntry>> history(String uid, {int limit = 60}) async {
    final snap = await _col(uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
    final entries = snap.docs
        .map((d) => WeightEntry.fromMap(d.id, d.data()))
        .whereType<WeightEntry>()
        .toList();
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }
}
