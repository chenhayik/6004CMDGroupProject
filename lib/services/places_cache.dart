import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/fitness_place.dart';

/// On-device cache for nearby-gym searches, so re-opening the Radar (or panning
/// back over an area) renders instantly from disk instead of re-billing the
/// Places API. Backed by `SharedPreferencesAsync` (Jetpack DataStore on
/// Android) per the project's persistence rule — no third-party DB.
///
/// Entries are keyed by a coarse centre (rounded to ~100 m) plus radius, expire
/// after [_ttl], and are capped at [_maxEntries] (oldest evicted) so the store
/// never grows unbounded.
class PlacesCache {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static const _kEntries = 'radar_places_cache';
  static const _kLastLat = 'radar_last_lat';
  static const _kLastLng = 'radar_last_lng';
  static const _ttl = Duration(minutes: 30);
  static const _maxEntries = 12;

  // Round to 3 dp (~110 m) so small pans still hit the same cache bucket.
  String _key(double lat, double lng, int radiusM) =>
      '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)},$radiusM';

  Future<Map<String, dynamic>> _readAll() async {
    final s = await _prefs.getString(_kEntries);
    if (s == null) return {};
    try {
      return (jsonDecode(s) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  /// Fresh cached results for this area, or null on miss/expiry.
  Future<List<FitnessPlace>?> get(double lat, double lng, int radiusM) async {
    final all = await _readAll();
    final entry = all[_key(lat, lng, radiusM)] as Map?;
    if (entry == null) return null;

    final ts = (entry['ts'] as num?)?.toInt() ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - ts > _ttl.inMilliseconds) {
      return null;
    }
    final list = (entry['places'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((m) => FitnessPlace.fromCache(m.cast<String, dynamic>()))
        .toList();
  }

  Future<void> put(
    double lat,
    double lng,
    int radiusM,
    List<FitnessPlace> places,
  ) async {
    final all = await _readAll();
    all[_key(lat, lng, radiusM)] = {
      'ts': DateTime.now().millisecondsSinceEpoch,
      'places': places.map((p) => p.toCache()).toList(),
    };

    // Evict oldest if over capacity.
    if (all.length > _maxEntries) {
      final sorted = all.entries.toList()
        ..sort((a, b) => ((a.value as Map)['ts'] as num)
            .compareTo((b.value as Map)['ts'] as num));
      for (final e in sorted.take(all.length - _maxEntries)) {
        all.remove(e.key);
      }
    }
    await _prefs.setString(_kEntries, jsonEncode(all));
  }

  // ── Last map centre, so a cold start can position the camera instantly ──
  Future<void> saveLastCenter(double lat, double lng) async {
    await _prefs.setString(_kLastLat, lat.toString());
    await _prefs.setString(_kLastLng, lng.toString());
  }

  Future<({double lat, double lng})?> lastCenter() async {
    final lat = double.tryParse(await _prefs.getString(_kLastLat) ?? '');
    final lng = double.tryParse(await _prefs.getString(_kLastLng) ?? '');
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }
}
