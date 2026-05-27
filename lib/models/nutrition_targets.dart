
class NutritionTargets {
  final int bmr;
  final int tdee;
  final int targetCalories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final double proteinKcal;
  final double carbsKcal;
  final double fatKcal;

  NutritionTargets({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.proteinKcal,
    required this.carbsKcal,
    required this.fatKcal,
  });

  Map<String, dynamic> toMap() {
    return {
      'bmr': bmr,
      'tdee': tdee,
      'targetCalories': targetCalories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
      'proteinKcal': proteinKcal,
      'carbsKcal': carbsKcal,
      'fatKcal': fatKcal,
    };
  }
}