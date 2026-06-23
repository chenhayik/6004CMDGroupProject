import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/meal_result.dart';

/// An error whose [message] is already safe to show to the user — no stack
/// traces, API codes, or internal jargon. Anything thrown as this can be shown
/// verbatim; anything else should be mapped to a friendly fallback first.
class MealScanException implements Exception {
  final String message;
  const MealScanException(this.message);
  @override
  String toString() => message;
}

class GeminiService {
  // ── API key is supplied at build time, never hardcoded ──
  // Pass it via:  flutter run --dart-define=GEMINI_API_KEY=your_key
  // (or --dart-define-from-file=env.json). Keeping the key out of source means
  // it can't be committed to git. Get one at https://aistudio.google.com/app/apikey
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  // ── Input guards ──
  static const int _maxImageBytes = 4 * 1024 * 1024; // 4 MB
  static const Duration _requestTimeout = Duration(seconds: 30);

  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'models/gemini-3.1-flash-lite',
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
    if (_apiKey.isEmpty) {
      debugPrint('GEMINI_API_KEY not set — pass --dart-define-from-file=env.json');
      throw const MealScanException(
        'Photo analysis is unavailable right now. Please try again later.',
      );
    }

    // ── Validate the image before spending an API call ──
    final mimeType = _validateImage(imageBytes);

    try {
      final prompt = TextPart(
        'You are a professional nutritionist. Analyze this food image carefully. '
            'Identify the food or meal shown and estimate the macronutrients for the '
            'visible portion size. Be as accurate as possible. '
            'If multiple foods are visible, estimate the total combined macros.',
      );

      final imagePart = DataPart(mimeType, imageBytes);

      final response = await _model.generateContent([
        Content.multi([prompt, imagePart]),
      ]).timeout(_requestTimeout);

      final jsonText = response.text;

      if (jsonText == null || jsonText.isEmpty) {
        throw const MealScanException(
            "We couldn't analyse this photo. Please try a clearer one.");
      }

      debugPrint('Gemini raw response: $jsonText');

      // ── Parse JSON → MealResult ──
      final Map<String, dynamic> parsed = jsonDecode(jsonText);
      return MealResult.fromJson(parsed);

    } on MealScanException {
      rethrow; // already a friendly, user-safe message
    } on GenerativeAIException catch (e) {
      debugPrint('Gemini API error: ${e.message}');
      final m = e.message.toLowerCase();
      if (m.contains('quota') ||
          m.contains('exhausted') ||
          m.contains('credit') ||
          m.contains('billing') ||
          m.contains('rate limit')) {
        throw const MealScanException(
            'Photo analysis is temporarily unavailable (usage limit '
            'reached). Please try again later.');
      }
      throw const MealScanException(
          "We couldn't analyse this photo. Please try again.");
    } on FormatException catch (e) {
      debugPrint('Meal scan parse error: $e');
      throw const MealScanException(
          "We couldn't read the result. Please try another photo.");
    } on TimeoutException {
      throw const MealScanException(
          'This is taking too long — check your connection and try again.');
    } catch (e) {
      debugPrint('Meal scan unexpected error: $e');
      throw const MealScanException(
          'Something went wrong analysing your photo. Please try again.');
    }
  }

  /// Validates that [bytes] is a non-empty, reasonably sized, real image and
  /// returns its MIME type. Throws a friendly [Exception] otherwise so we never
  /// upload arbitrary or oversized payloads to the API.
  String _validateImage(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const MealScanException('No image data — please retake the photo.');
    }
    if (bytes.lengthInBytes > _maxImageBytes) {
      throw const MealScanException(
          'Image is too large. Please use a smaller photo.');
    }

    // Magic-byte sniffing — don't trust the file extension or picker.
    // JPEG: FF D8 FF | PNG: 89 50 4E 47
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }

    throw const MealScanException(
        'Unsupported image format. Please use a JPEG or PNG photo.');
  }
}