import 'package:cloud_firestore/cloud_firestore.dart';

class MealResult {
  final String? id;           // Firestore document ID
  final String foodName;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final DateTime? loggedAt;

  const MealResult({
    this.id,
    required this.foodName,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.loggedAt,
  });

  // ── From Gemini JSON response ──
  factory MealResult.fromJson(Map<String, dynamic> json) {
    return MealResult(
      foodName: json['food_name']?.toString() ?? 'Unknown Food',
      calories: _parseInt(json['calories']),
      proteinG: _parseInt(json['protein_g']),
      carbsG:   _parseInt(json['carbs_g']),
      fatG:     _parseInt(json['fat_g']),
    );
  }

  // ── From Firestore document ──
  factory MealResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealResult(
      id:       doc.id,
      foodName: data['food_name'] ?? 'Unknown Food',
      calories: _parseInt(data['calories']),
      proteinG: _parseInt(data['protein_g']),
      carbsG:   _parseInt(data['carbs_g']),
      fatG:     _parseInt(data['fat_g']),
      loggedAt: (data['logged_at'] as Timestamp?)?.toDate(),
    );
  }

  // ── To Firestore map ──
  Map<String, dynamic> toFirestore() {
    return {
      'food_name':  foodName,
      'calories':   calories,
      'protein_g':  proteinG,
      'carbs_g':    carbsG,
      'fat_g':      fatG,
      'logged_at':  FieldValue.serverTimestamp(),
    };
  }

  // ── Safe int parser ──
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }
}