import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_application_group/services/macro_math.dart';

void main() {
  const balanced = (0.30, 0.40, 0.30); // protein, carbs, fat

  group('compute — Mifflin–St Jeor', () {
    test('male, maintain: hand-verified BMR/TDEE/macros', () {
      // 80 kg, 180 cm, 30 y, moderate (×1.55), maintain, balanced split.
      // BMR  = 10*80 + 6.25*180 - 5*30 + 5            = 1780
      // TDEE = 1780 * 1.55                            = 2759
      // protein = 2759*0.30/4 ≈ 207, carbs = 2759*0.40/4 ≈ 276,
      // fat     = 2759*0.30/9 ≈ 92
      final t = MacroMath.compute(
        weightKg: 80,
        heightCm: 180,
        age: 30,
        sex: 'male',
        activityLevel: 'Moderately active',
        goal: 'maintain',
        split: balanced,
      );
      expect(t.bmr, 1780);
      expect(t.tdee, 2759);
      expect(t.targetCalories, 2759);
      expect(t.proteinG, 207);
      expect(t.carbsG, 276);
      expect(t.fatG, 92);
    });

    test('female formula uses the −161 constant', () {
      // 60 kg, 165 cm, 25 y → BMR = 600 + 1031.25 - 125 - 161 = 1345.25 → 1345
      final t = MacroMath.compute(
        weightKg: 60,
        heightCm: 165,
        age: 25,
        sex: 'female',
        activityLevel: 'sedentary',
        goal: 'maintain',
        split: balanced,
      );
      expect(t.bmr, 1345);
    });

    test('macro calories reconstruct the target (4/4/9 kcal per g)', () {
      final t = MacroMath.compute(
        weightKg: 80,
        heightCm: 180,
        age: 30,
        sex: 'male',
        activityLevel: 'Moderately active',
        goal: 'maintain',
        split: balanced,
      );
      final kcalFromMacros = t.proteinG * 4 + t.carbsG * 4 + t.fatG * 9;
      // Within rounding error of the calorie target.
      expect((kcalFromMacros - t.targetCalories).abs(), lessThanOrEqualTo(5));
    });
  });

  group('goal adjustment', () {
    MacroTargets forGoal(String goal) => MacroMath.compute(
          weightKg: 80,
          heightCm: 180,
          age: 30,
          sex: 'male',
          activityLevel: 'Moderately active', // TDEE = 2759
          goal: goal,
          split: balanced,
        );

    test('cut subtracts 500, bulk adds 300, maintain is unchanged', () {
      expect(forGoal('maintain').targetCalories, 2759);
      expect(forGoal('cut').targetCalories, 2759 - 500);
      expect(forGoal('bulk').targetCalories, 2759 + 300);
    });
  });

  group('safe-minimum calorie floor', () {
    test('female cut never drops below 1200', () {
      // Small person on a cut would compute well under 1200.
      final t = MacroMath.compute(
        weightKg: 50,
        heightCm: 155,
        age: 25,
        sex: 'female',
        activityLevel: 'sedentary',
        goal: 'cut',
        split: balanced,
      );
      expect(t.targetCalories, 1200);
    });

    test('male floor is 1500', () {
      final t = MacroMath.compute(
        weightKg: 50,
        heightCm: 160,
        age: 25,
        sex: 'male',
        activityLevel: 'sedentary',
        goal: 'cut',
        split: balanced,
      );
      expect(t.targetCalories, 1500);
    });
  });

  group('activityMultiplier', () {
    test('maps each level, matching on substrings', () {
      expect(MacroMath.activityMultiplier('sedentary'), 1.2);
      expect(MacroMath.activityMultiplier('Lightly active'), 1.375);
      expect(MacroMath.activityMultiplier('Moderately active'), 1.55);
      expect(MacroMath.activityMultiplier('Very active'), 1.725);
      expect(MacroMath.activityMultiplier('Extra active'), 1.9);
    });

    test('unknown / empty falls back to sedentary (1.2)', () {
      expect(MacroMath.activityMultiplier(''), 1.2);
      expect(MacroMath.activityMultiplier('astronaut'), 1.2);
    });
  });
}
