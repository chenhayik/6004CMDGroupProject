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
  // The model output is untrusted: clamp macros to sane ranges and sanitize
  // the name so absurd or malicious values never reach the UI / Firestore.
  factory MealResult.fromJson(Map<String, dynamic> json) {
    return MealResult(
      foodName: _sanitizeName(json['food_name']),
      calories: _parseInt(json['calories']).clamp(0, 10000),
      proteinG: _parseInt(json['protein_g']).clamp(0, 1000),
      carbsG:   _parseInt(json['carbs_g']).clamp(0, 1000),
      fatG:     _parseInt(json['fat_g']).clamp(0, 1000),
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

  // ── Sanitize a food name from an untrusted source ──
  // Strips control characters, collapses whitespace, and caps the length so a
  // hostile or malformed response can't inject odd characters or huge strings.
  static String _sanitizeName(dynamic value) {
    final raw = value?.toString() ?? '';
    final cleaned = raw
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '') // control chars
        .replaceAll(RegExp(r'\s+'), ' ')            // collapse whitespace
        .trim();
    if (cleaned.isEmpty) return 'Unknown Food';
    return cleaned.length > 100 ? cleaned.substring(0, 100) : cleaned;
  }
}