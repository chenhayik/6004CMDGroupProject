import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/fitness_place.dart';

/// Thrown when the Maps/Places key is missing so the UI can show a clear
/// "set MAPS_API_KEY" message instead of a generic network error.
class PlacesKeyMissing implements Exception {
  @override
  String toString() => 'MAPS_API_KEY not set (--dart-define-from-file=env.json).';
}

/// Calls the **Places API (New)** `places:searchNearby` endpoint directly over
/// REST. A thin client (no heavyweight wrapper package) keeps the app small and
/// lets us send a tight `X-Goog-FieldMask`, which both shrinks the payload and
/// keeps billing in the cheaper SKU.
class PlacesService {
  static const String _apiKey = String.fromEnvironment('MAPS_API_KEY');
  static const _endpoint =
      'https://places.googleapis.com/v1/places:searchNearby';
  static const Duration _timeout = Duration(seconds: 12);

  // Only the fields the Radar actually renders — nothing more.
  static const _fieldMask = 'places.id,'
      'places.displayName,'
      'places.location,'
      'places.types,'
      'places.currentOpeningHours.openNow,'
      'places.rating,'
      'places.userRatingCount';

  bool get hasKey => _apiKey.isNotEmpty;

  /// Nearest gyms within [radiusMeters] of ([lat], [lng]), nearest first.
  Future<List<FitnessPlace>> searchNearby({
    required double lat,
    required double lng,
    required int radiusMeters,
    int maxResults = 20,
  }) async {
    if (_apiKey.isEmpty) throw PlacesKeyMissing();

    final body = jsonEncode({
      'includedTypes': ['gym'],
      'maxResultCount': maxResults.clamp(1, 20),
      'rankPreference': 'DISTANCE',
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radiusMeters.toDouble(),
        },
      },
    });

    final res = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey,
            'X-Goog-FieldMask': _fieldMask,
          },
          body: body,
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      debugPrint('Places searchNearby ${res.statusCode}: ${res.body}');
      throw Exception('Places request failed (${res.statusCode}).');
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final places = (decoded['places'] as List?) ?? const [];
    return places
        .whereType<Map>()
        .map((m) => FitnessPlace.fromPlacesJson(m.cast<String, dynamic>()))
        .where((p) => p.id.isNotEmpty)
        .toList();
  }
}
