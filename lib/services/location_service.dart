import 'package:geolocator/geolocator.dart';

/// Outcome of asking for a location fix, so the UI can show the right state
/// (granted → map, denied → CTA, serviceOff → "turn on location").
enum LocationStatus { granted, denied, deniedForever, serviceDisabled }

class LocationResult {
  final LocationStatus status;
  final Position? position;
  const LocationResult(this.status, [this.position]);
  bool get ok => status == LocationStatus.granted && position != null;
}

/// Thin wrapper over Geolocator. One-shot fixes only (no continuous stream) to
/// keep the Fitness Radar light on battery; the last fix is cached by the
/// caller so cold starts can centre the map instantly.
class LocationService {
  /// Kuala Lumpur city centre — the fallback map centre when we have no fix.
  static const double fallbackLat = 3.1390;
  static const double fallbackLng = 101.6869;

  /// Last-known position from the OS cache — returns immediately, may be null.
  Future<Position?> lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// Ensure permission + service, then return a fresh medium-accuracy fix.
  Future<LocationResult> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult(LocationStatus.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(LocationStatus.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult(LocationStatus.denied);
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult(LocationStatus.granted, pos);
    } catch (_) {
      // Timed out / transient failure — fall back to last known if we have it.
      final last = await lastKnown();
      return last != null
          ? LocationResult(LocationStatus.granted, last)
          : const LocationResult(LocationStatus.denied);
    }
  }

  /// Opens the OS settings page so a "denied forever" user can re-enable.
  Future<void> openSettings() => Geolocator.openAppSettings();
}
