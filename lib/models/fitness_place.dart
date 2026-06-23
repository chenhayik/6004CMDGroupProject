import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Coarse facility classification used by the Fitness Radar filter chips.
/// Places API (New) only exposes a generic "gym" type, so anything more
/// specific (powerlifting, calisthenics, CrossFit) is inferred from the name.
enum FacilityType { gym, powerlifting, calisthenics, crossfit, specialized }

extension FacilityTypeLabel on FacilityType {
  String get label {
    switch (this) {
      case FacilityType.gym:
        return 'Gym';
      case FacilityType.powerlifting:
        return 'Powerlifting';
      case FacilityType.calisthenics:
        return 'Calisthenics';
      case FacilityType.crossfit:
        return 'CrossFit';
      case FacilityType.specialized:
        return 'Specialized';
    }
  }
}

/// A nearby gym / fitness facility returned by the Places API (New).
///
/// Kept deliberately small: only the fields requested in the `X-Goog-FieldMask`
/// are parsed, so payloads stay tiny and Places billing stays in the cheaper
/// SKU. [distanceMeters] is filled in client-side (Geolocator) after fetch.
class FitnessPlace {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final FacilityType type;
  final bool? openNow;
  final double? rating;
  final int? userRatingCount;

  /// Straight-line distance from the search centre, set by the ViewModel.
  double? distanceMeters;

  FitnessPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.type,
    this.openNow,
    this.rating,
    this.userRatingCount,
    this.distanceMeters,
  });

  LatLng get position => LatLng(lat, lng);

  /// "1.2 km" / "350 m" — empty when distance is unknown.
  String get distanceLabel {
    final d = distanceMeters;
    if (d == null) return '';
    return d < 1000 ? '${d.round()} m' : '${(d / 1000).toStringAsFixed(1)} km';
  }

  // ── Places API (New) `places:searchNearby` item ──
  factory FitnessPlace.fromPlacesJson(Map<String, dynamic> json) {
    final loc = (json['location'] as Map?)?.cast<String, dynamic>() ?? const {};
    final displayName =
        (json['displayName'] as Map?)?.cast<String, dynamic>() ?? const {};
    final hours = (json['currentOpeningHours'] as Map?)?.cast<String, dynamic>();
    final name = (displayName['text'] as String?)?.trim() ?? 'Unnamed gym';

    return FitnessPlace(
      id: json['id'] as String? ?? '',
      name: name,
      lat: (loc['latitude'] as num?)?.toDouble() ?? 0,
      lng: (loc['longitude'] as num?)?.toDouble() ?? 0,
      type: _classify(name),
      openNow: hours?['openNow'] as bool?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingCount: (json['userRatingCount'] as num?)?.toInt(),
    );
  }

  // ── DataStore cache round-trip (see PlacesCache) ──
  Map<String, dynamic> toCache() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'type': type.name,
        'openNow': openNow,
        'rating': rating,
        'userRatingCount': userRatingCount,
      };

  factory FitnessPlace.fromCache(Map<String, dynamic> m) => FitnessPlace(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? 'Unnamed gym',
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        type: FacilityType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => FacilityType.gym,
        ),
        openNow: m['openNow'] as bool?,
        rating: (m['rating'] as num?)?.toDouble(),
        userRatingCount: (m['userRatingCount'] as num?)?.toInt(),
      );

  /// Infer a finer facility type from the venue name. Cheap keyword match —
  /// good enough to drive the filter chips without an extra paid Places field.
  static FacilityType _classify(String name) {
    final n = name.toLowerCase();
    if (n.contains('powerlift') ||
        n.contains('barbell') ||
        n.contains('strength') ||
        n.contains('iron')) {
      return FacilityType.powerlifting;
    }
    if (n.contains('calisthenic') || n.contains('street workout')) {
      return FacilityType.calisthenics;
    }
    if (n.contains('crossfit') || n.contains('cross fit')) {
      return FacilityType.crossfit;
    }
    if (n.contains('boxing') ||
        n.contains('muay') ||
        n.contains('mma') ||
        n.contains('martial') ||
        n.contains('pilates') ||
        n.contains('yoga') ||
        n.contains('climb')) {
      return FacilityType.specialized;
    }
    return FacilityType.gym;
  }
}
