import 'package:cloud_firestore/cloud_firestore.dart';

/// One body-weight measurement (one per calendar day, latest wins).
class WeightEntry {
  final DateTime date; // local midnight of the logged day
  final double weightKg;

  const WeightEntry({required this.date, required this.weightKg});

  static WeightEntry? fromMap(String id, Map<String, dynamic> m) {
    final dayKey = (m['date'] as String?) ?? id;
    final date = DateTime.tryParse(dayKey);
    final kg = (m['weight_kg'] as num?)?.toDouble();
    if (date == null || kg == null) return null;
    return WeightEntry(
      date: DateTime(date.year, date.month, date.day),
      weightKg: kg,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String().substring(0, 10),
        'weight_kg': weightKg,
        'logged_at': FieldValue.serverTimestamp(),
      };
}
