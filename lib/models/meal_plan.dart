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

  /// Estimated single-serving price in MYR (hawker / mamak / economy-rice).
  /// 0 when unknown (e.g. a plan cached before pricing was added).
  final double priceMyr;

  const MealPlanItem({
    required this.slot,
    required this.name,
    required this.description,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.isWildcard,
    this.priceMyr = 0,
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
        priceMyr: _double(m['price_myr']),
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
        'price_myr': priceMyr,
      };

  /// "RM 6" / "RM 6.50" — empty when the price is unknown.
  String get priceLabel => priceMyr <= 0 ? '' : fmtMyr(priceMyr);

  /// Formats a MYR amount, dropping the decimals when it's a whole number.
  static String fmtMyr(double v) {
    final whole = v == v.roundToDouble();
    return 'RM ${whole ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? 0;
  }

  static double _double(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
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

  double get totalPrice => meals.fold(0.0, (s, m) => s + m.priceMyr);

  /// "RM 22" day total — empty when no meal carries a price.
  String get totalPriceLabel =>
      totalPrice <= 0 ? '' : MealPlanItem.fmtMyr(totalPrice);
}
