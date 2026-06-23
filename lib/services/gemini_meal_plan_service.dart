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
    List<String> cuisines = const [],
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
      cuisines: cuisines,
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
        'price_myr': Schema(SchemaType.number,
            description: 'estimated single-serving price in Malaysian Ringgit '
                '(MYR) at a hawker / mamak / economy-rice stall'),
      },
      requiredProperties: [
        'slot',
        'name',
        'calories',
        'protein_g',
        'carbs_g',
        'fat_g',
        'is_wildcard',
        'price_myr',
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
    List<String> cuisines = const [],
  }) {
    final recent =
        recentMealNames.isEmpty ? 'none yet' : recentMealNames.join(', ');
    final cuisineLine = cuisines.isEmpty
        ? 'Use a varied mix across Malay, Chinese, Indian, Thai and Western '
            'dishes over the week.'
        : 'Use ONLY ${cuisines.join(' and ')} food — EVERY single meal must be '
            '${cuisines.join(' or ')}. Do NOT include dishes from any other '
            'cuisine. Keep good variety within '
            '${cuisines.length > 1 ? 'these cuisines' : 'this cuisine'} across '
            'the 7 days.';
    return '''
You are a Malaysian dietitian and weekly meal planner. Produce a 7-day plan with
breakfast, lunch, and dinner using everyday, affordable food Malaysians actually
eat across all communities: Malay (nasi lemak, nasi campur, soto), Chinese
(chicken rice, char kuey teow, wantan mee, economy rice), Indian (banana-leaf
rice, roti canai with dhal, thosai, mee goreng), Thai (tom yam, green curry,
basil chicken rice), and Western / Hainanese kopitiam fare (chicken chop, lamb
chop, fish & chips, spaghetti).

CUISINE PREFERENCE: $cuisineLine

HARD RULES:
1. Each DAY's three meals must SUM to roughly the user's daily targets:
   $kcal kcal, ${protein}g protein, ${carbs}g carbs, ${fat}g fat.
   Keep each day within ±8% on calories and within ±10% on protein.
2. STAPLE-BASED: build every meal around a carbohydrate staple. Local meals are
   usually rice-based (white rice / nasi, nasi lemak, nasi goreng, economy rice)
   or noodles / bread / roti; Western dishes come with fries, wedges, mashed
   potato or bread. NEVER serve a protein or vegetable dish on its own — no plain
   grilled fish, plain yong tau foo, or steamed chicken with only cucumber. Pair
   it with a staple and name it that way, e.g. "Ikan Bakar with Nasi",
   "Yong Tau Foo with Rice", "Chicken Chop with Fries & Coleslaw".
3. ECONOMICAL: favour cheap, everyday dishes at typical hawker / mamak /
   economy-rice prices. Breakfast and lunch especially must be budget-friendly
   (e.g. nasi lemak, roti canai, economy rice with 1 meat + 1 veg, mee goreng,
   chee cheong fun). Avoid premium, restaurant-style, or imported ingredients.
   For every meal give "price_myr" — a realistic single-serving price in MYR
   (e.g. roti canai RM 1.50–3, nasi lemak RM 3–6, mee goreng RM 5–7, economy
   rice RM 6–9, chicken rice RM 7–10). Keep breakfast and lunch the cheapest
   meals of the day.
4. Give realistic single-serving portions and honest per-meal macro estimates
   (integers). The three meals' macros must add up to the day total.
5. VARIETY: never repeat the same main dish across the 7 days, and avoid dishes
   similar to the user's recent meals listed below.
6. WILDCARD: exactly once in the week, mark one meal "is_wildcard": true — an
   indulgent local treat (e.g. cendol, ABC, durian, char kuey teow) — and lighten
   the other two meals that day so the day still hits target.
7. Halal-friendly, widely available, no alcohol.
8. Use day_offset 0..6 (0 = today), each day with exactly 3 meals
   (slot = breakfast, lunch, dinner). Output ONLY JSON matching the schema.

USER
- Goal: $goal
- Daily targets: $kcal kcal · P${protein}g · C${carbs}g · F${fat}g
- Recent meals to avoid repeating: $recent
''';
  }
}
