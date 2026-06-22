/// One planned meal for a slot in the weekly plan.
class MealPlanItem {
  final String slot; // breakfast | lunch | dinner
  final String name;
  final String description;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final bool isWildcard;

  const MealPlanItem({
    required this.slot,
    required this.name,
    required this.description,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.isWildcard,
  });

  factory MealPlanItem.fromMap(Map<String, dynamic> m) => MealPlanItem(
        slot: (m['slot'] ?? 'meal').toString(),
        name: (m['name'] ?? 'Meal').toString(),
        description: (m['description'] ?? '').toString(),
        calories: _int(m['calories']),
        proteinG: _int(m['protein_g']),
        carbsG: _int(m['carbs_g']),
        fatG: _int(m['fat_g']),
        isWildcard: m['is_wildcard'] == true,
      );

  Map<String, dynamic> toMap() => {
        'slot': slot,
        'name': name,
        'description': description,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'is_wildcard': isWildcard,
      };

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? 0;
  }
}

/// One day of the weekly plan (offset 0 = the day the plan was generated).
class DayPlan {
  final int dayOffset; // 0..6
  final List<MealPlanItem> meals;

  const DayPlan({required this.dayOffset, required this.meals});

  factory DayPlan.fromMap(Map<String, dynamic> m) => DayPlan(
        dayOffset: MealPlanItem._int(m['day_offset']),
        meals: ((m['meals'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => MealPlanItem.fromMap(e.cast<String, dynamic>()))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'day_offset': dayOffset,
        'meals': meals.map((e) => e.toMap()).toList(),
      };

  int get totalCalories => meals.fold(0, (s, m) => s + m.calories);
  int get totalProtein => meals.fold(0, (s, m) => s + m.proteinG);
  int get totalCarbs => meals.fold(0, (s, m) => s + m.carbsG);
  int get totalFat => meals.fold(0, (s, m) => s + m.fatG);
}
