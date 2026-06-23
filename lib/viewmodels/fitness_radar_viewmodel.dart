import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/fitness_place.dart';
import '../services/location_service.dart';
import '../services/places_cache.dart';
import '../services/places_service.dart';

enum RadarStatus { loading, ready, error }

/// Drives the Fitness Radar map + result list. Performance-minded:
///   • renders cached markers first, then refreshes in the background;
///   • only re-hits Places when the *query* changes (radius / "search here") —
///     the Open-now and type chips filter the already-fetched list in memory;
///   • debounces radius changes so dragging the slider fires one request.
class FitnessRadarViewModel extends ChangeNotifier {
  final PlacesService _places = PlacesService();
  final PlacesCache _cache = PlacesCache();
  final LocationService _location = LocationService();

  RadarStatus status = RadarStatus.loading;
  String? error;
  LocationStatus? permission;

  LatLng center =
      const LatLng(LocationService.fallbackLat, LocationService.fallbackLng);
  bool hasFix = false;

  // ── Filters ──
  double radiusKm = 5;
  bool openNowOnly = false;
  final Set<FacilityType> typeFilter = {};

  // ── Results ──
  List<FitnessPlace> _all = [];
  bool searching = false;
  bool showSearchHere = false;
  String? selectedId;

  Timer? _debounce;
  LatLng? _pendingCenter;
  bool _disposed = false;

  int get radiusMeters => (radiusKm * 1000).round();
  bool get keyMissing => !_places.hasKey;

  /// Filtered + nearest-first, capped so we never render a wall of markers.
  List<FitnessPlace> get places {
    Iterable<FitnessPlace> list = _all;
    if (openNowOnly) list = list.where((p) => p.openNow == true);
    if (typeFilter.isNotEmpty) {
      list = list.where((p) => typeFilter.contains(p.type));
    }
    final out = list.toList()
      ..sort((a, b) =>
          (a.distanceMeters ?? 1e12).compareTo(b.distanceMeters ?? 1e12));
    return out.length > 25 ? out.sublist(0, 25) : out;
  }

  // ─── Lifecycle ───────────────────────────────────────────
  Future<void> init() async {
    // 1) Instant paint: last centre + any cached results for it.
    final last = await _cache.lastCenter();
    if (last != null) {
      center = LatLng(last.lat, last.lng);
    } else {
      final lk = await _location.lastKnown();
      if (lk != null) center = LatLng(lk.latitude, lk.longitude);
    }
    final cached =
        await _cache.get(center.latitude, center.longitude, radiusMeters);
    if (cached != null) {
      _all = cached;
      _recomputeDistances();
      status = RadarStatus.ready;
      notifyListeners();
    }

    // 2) Fresh fix → re-centre → fetch.
    final res = await _location.currentPosition();
    permission = res.status;
    if (res.ok) {
      hasFix = true;
      center = LatLng(res.position!.latitude, res.position!.longitude);
      await _cache.saveLastCenter(center.latitude, center.longitude);
    }
    await _fetch();
  }

  Future<void> _fetch() async {
    searching = true;
    showSearchHere = false;
    if (_all.isEmpty) status = RadarStatus.loading;
    notifyListeners();
    try {
      final result = await _places.searchNearby(
        lat: center.latitude,
        lng: center.longitude,
        radiusMeters: radiusMeters,
      );
      _all = result;
      _recomputeDistances();
      await _cache.put(
          center.latitude, center.longitude, radiusMeters, result);
      error = null;
      status = RadarStatus.ready;
    } on PlacesKeyMissing {
      error = 'Map search needs a Maps API key (MAPS_API_KEY).';
      if (_all.isEmpty) status = RadarStatus.error;
    } catch (e) {
      debugPrint('Radar fetch error: $e');
      error = 'Could not load nearby gyms. Check your connection.';
      if (_all.isEmpty) status = RadarStatus.error;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  void _recomputeDistances() {
    for (final p in _all) {
      p.distanceMeters = Geolocator.distanceBetween(
          center.latitude, center.longitude, p.lat, p.lng);
    }
  }

  // ─── Map interaction ─────────────────────────────────────
  /// Called on camera idle. Surfaces a "Search this area" button once the user
  /// has panned far enough — we don't auto-query on every pan (costs money).
  void onCameraIdle(LatLng target) {
    _pendingCenter = target;
    final moved = Geolocator.distanceBetween(
        center.latitude, center.longitude, target.latitude, target.longitude);
    final shouldShow = moved > 400;
    if (shouldShow != showSearchHere) {
      showSearchHere = shouldShow;
      notifyListeners();
    }
  }

  Future<void> searchHere() async {
    if (_pendingCenter != null) center = _pendingCenter!;
    await _cache.saveLastCenter(center.latitude, center.longitude);
    final cached =
        await _cache.get(center.latitude, center.longitude, radiusMeters);
    if (cached != null) {
      _all = cached;
      _recomputeDistances();
      status = RadarStatus.ready;
      notifyListeners();
    }
    await _fetch();
  }

  // ─── Filters ─────────────────────────────────────────────
  void setRadius(double km) {
    if (km == radiusKm) return;
    radiusKm = km;
    notifyListeners();
    // Radius changes the query → refetch, debounced so dragging fires once.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _fetch);
  }

  void toggleOpenNow() {
    openNowOnly = !openNowOnly;
    notifyListeners();
  }

  void toggleType(FacilityType t) {
    if (!typeFilter.remove(t)) typeFilter.add(t);
    notifyListeners();
  }

  void select(String? id) {
    if (id == selectedId) return;
    selectedId = id;
    notifyListeners();
  }

  Future<void> refresh() => _fetch();

  // Async work (location fix, Places fetch) can complete after the user has
  // left the screen and the provider has disposed us — swallow those notifies
  // instead of throwing "used after dispose".
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
