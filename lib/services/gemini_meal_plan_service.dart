import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/meal_plan.dart';

/// Calls Gemini to generate a 7-day Malaysian meal plan that hits the user's
/// daily macro targets. Uses structured output (responseSchema) so the result
/// is always a parsable JSON array — same reliability pattern as GeminiService.
class GeminiMealPlanService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const Duration _timeout = Duration(seconds: 45);

  late final GenerativeModel _model;

  GeminiMealPlanService() {
    _model = GenerativeModel(
      model: 'models/gemini-3.1-flash-lite',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _weekSchema(),
      ),
    );
  }

  Future<List<DayPlan>> generateWeek({
    required int kcal,
    required int protein,
    required int carbs,
    required int fat,
    required String goal,
    required List<String> recentMealNames,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('Gemini API key not set '
          '(--dart-define=GEMINI_API_KEY=...).');
    }

    final prompt = _buildPrompt(
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      goal: goal,
      recentMealNames: recentMealNames,
    );

    final res =
        await _model.generateContent([Content.text(prompt)]).timeout(_timeout);
    final text = res.text;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini returned an empty meal plan.');
    }
    debugPrint('Meal plan raw: ${text.length} chars');

    final decoded = jsonDecode(text);
    if (decoded is! List) {
      throw Exception('Meal plan was not a JSON array.');
    }
    final days = decoded
        .whereType<Map>()
        .map((m) => DayPlan.fromMap(m.cast<String, dynamic>()))
        .where((d) => d.meals.isNotEmpty)
        .toList()
      ..sort((a, b) => a.dayOffset.compareTo(b.dayOffset));

    if (days.isEmpty) {
      throw Exception('Meal plan had no usable days.');
    }
    return days;
  }

  // ── Structured-output schema: array of 7 day objects ──
  Schema _weekSchema() {
    final meal = Schema(
      SchemaType.object,
      properties: {
        'slot': Schema(SchemaType.string,
            description: 'breakfast | lunch | dinner'),
        'name': Schema(SchemaType.string, description: 'Malaysian dish name'),
        'description': Schema(SchemaType.string,
            description: 'one short line: portion / how it is served'),
        'calories': Schema(SchemaType.integer),
        'protein_g': Schema(SchemaType.integer),
        'carbs_g': Schema(SchemaType.integer),
        'fat_g': Schema(SchemaType.integer),
        'is_wildcard': Schema(SchemaType.boolean),
      },
      requiredProperties: [
        'slot',
        'name',
        'calories',
        'protein_g',
        'carbs_g',
        'fat_g',
        'is_wildcard',
      ],
    );

    return Schema(
      SchemaType.array,
      items: Schema(
        SchemaType.object,
        properties: {
          'day_offset':
              Schema(SchemaType.integer, description: '0 = today … 6'),
          'meals': Schema(SchemaType.array, items: meal),
        },
        requiredProperties: ['day_offset', 'meals'],
      ),
    );
  }

  String _buildPrompt({
    required int kcal,
    required int protein,
    required int carbs,
    required int fat,
    required String goal,
    required List<String> recentMealNames,
  }) {
    final recent =
        recentMealNames.isEmpty ? 'none yet' : recentMealNames.join(', ');
    return '''
You are a Malaysian dietitian and weekly meal planner. Produce a 7-day plan with
breakfast, lunch, and dinner using everyday Malaysian foods — kopitiam, hawker
centre, mamak, and home-cooked dishes (e.g. nasi lemak, chicken rice, roti canai,
char kuey teow, laksa, economy rice / nasi campur, soto, yong tau foo, ABC).

HARD RULES:
1. Each DAY's three meals must SUM to roughly the user's daily targets:
   $kcal kcal, ${protein}g protein, ${carbs}g carbs, ${fat}g fat.
   Keep each day within ±8% on calories and within ±10% on protein.
2. Give realistic single-serving portions and honest per-meal macro estimates
   (integers). The three meals' macros must add up to the day total.
3. VARIETY: never repeat the same main dish across the 7 days, and avoid dishes
   similar to the user's recent meals listed below.
4. WILDCARD: exactly once in the week, mark one meal "is_wildcard": true — an
   indulgent local treat (e.g. cendol, char kuey teow, durian) — and lighten the
   other two meals that day so the day still hits target.
5. Halal-friendly, widely available, no alcohol.
6. Use day_offset 0..6 (0 = today), each day with exactly 3 meals
   (slot = breakfast, lunch, dinner). Output ONLY JSON matching the schema.

USER
- Goal: $goal
- Daily targets: $kcal kcal · P${protein}g · C${carbs}g · F${fat}g
- Recent meals to avoid repeating: $recent
''';
  }
}
