import 'package:cloud_firestore/cloud_firestore.dart';

// ── New model for nutrition targets ──
class NutritionTargets {
  final int bmr;
  final int tdee;
  final int targetCalories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final String macroRatio;

  NutritionTargets({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.macroRatio,
  });

  Map<String, dynamic> toMap() {
    return {
      'bmr': bmr,
      'tdee': tdee,
      'targetCalories': targetCalories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
      'macroRatio': macroRatio,
      'calculatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory NutritionTargets.fromMap(Map<String, dynamic> map) {
    return NutritionTargets(
      bmr: map['bmr'] ?? 0,
      tdee: map['tdee'] ?? 0,
      targetCalories: map['targetCalories'] ?? 0,
      proteinG: map['proteinG'] ?? 0,
      carbsG: map['carbsG'] ?? 0,
      fatG: map['fatG'] ?? 0,
      macroRatio: map['macroRatio'] ?? 'balanced',
    );
  }
}

// ── Existing UserProfile — add nutritionTargets field ──
class UserProfile {
  final String uid;
  final int age;
  final String biologicalSex;
  final double height;
  final double weight;
  final String activityLevel;
  final String goal;
  final NutritionTargets? nutritionTargets;  // ← new, nullable

  UserProfile({
    required this.uid,
    required this.age,
    required this.biologicalSex,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.goal,
    this.nutritionTargets,                   // ← optional
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'age': age,
      'biologicalSex': biologicalSex,
      'height': height,
      'weight': weight,
      'activityLevel': activityLevel,
      'goal': goal,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Only include nutritionTargets if it exists
    if (nutritionTargets != null) {
      map['nutritionTargets'] = nutritionTargets!.toMap();
    }

    return map;
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      age: (map['age'] as num?)?.toInt() ?? 0,
      biologicalSex: map['biologicalSex'] ?? '',
      height: (map['height'] as num?)?.toDouble() ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      activityLevel: map['activityLevel'] ?? '',
      goal: map['goal'] ?? '',
      nutritionTargets: map['nutritionTargets'] != null
          ? NutritionTargets.fromMap(map['nutritionTargets'])
          : null,
    );
  }
}