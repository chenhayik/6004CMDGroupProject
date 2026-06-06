import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/meal_result.dart';

class GeminiService {
  // ── Replace with your actual Gemini API key ──
  // Get one free at: https://aistudio.google.com/app/apikey
  static const String _apiKey = '';

  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'models/gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',

        // ── Strict schema: forces Gemini to always return these exact fields ──
        responseSchema: Schema(
          SchemaType.object,
          properties: {
            'food_name': Schema(
              SchemaType.string,
              description: 'The name of the food or meal identified in the image',
            ),
            'calories': Schema(
              SchemaType.integer,
              description: 'Estimated total calories (kcal) for the portion shown',
            ),
            'protein_g': Schema(
              SchemaType.integer,
              description: 'Estimated protein in grams',
            ),
            'carbs_g': Schema(
              SchemaType.integer,
              description: 'Estimated carbohydrates in grams',
            ),
            'fat_g': Schema(
              SchemaType.integer,
              description: 'Estimated fat in grams',
            ),
          },
          requiredProperties: [
            'food_name',
            'calories',
            'protein_g',
            'carbs_g',
            'fat_g',
          ],
        ),
      ),
    );
  }

  // ── Main analysis method ──
  Future<MealResult> analyzeImage(Uint8List imageBytes) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY') {
      throw Exception(
        'Gemini API key not set. Please replace YOUR_GEMINI_API_KEY in gemini_service.dart',
      );
    }

    try {
      final prompt = TextPart(
        'You are a professional nutritionist. Analyze this food image carefully. '
            'Identify the food or meal shown and estimate the macronutrients for the '
            'visible portion size. Be as accurate as possible. '
            'If multiple foods are visible, estimate the total combined macros.',
      );

      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await _model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final jsonText = response.text;

      if (jsonText == null || jsonText.isEmpty) {
        throw Exception('Gemini returned an empty response.');
      }

      debugPrint('Gemini raw response: $jsonText');

      // ── Parse JSON → MealResult ──
      final Map<String, dynamic> parsed = jsonDecode(jsonText);
      return MealResult.fromJson(parsed);

    } on GenerativeAIException catch (e) {
      throw Exception('Gemini API error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Failed to parse Gemini response as JSON: $e');
    } catch (e) {
      throw Exception('Unexpected error analysing image: $e');
    }
  }
}