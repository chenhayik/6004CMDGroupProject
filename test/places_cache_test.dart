import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_application_group/models/fitness_place.dart';
import 'package:mobile_application_group/services/places_cache.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    // Fresh in-memory store per test (no disk, no platform channels).
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  FitnessPlace place(String id, String name) => FitnessPlace(
        id: id,
        name: name,
        lat: 3.1,
        lng: 101.7,
        type: FacilityType.gym,
        openNow: true,
        rating: 4.5,
        userRatingCount: 10,
      );

  group('get / put round-trip', () {
    test('a fresh hit returns the stored places in order', () async {
      final cache = PlacesCache();
      await cache.put(3.1, 101.7, 1500, [place('a', 'Gym A'), place('b', 'Gym B')]);

      final got = await cache.get(3.1, 101.7, 1500);
      expect(got, isNotNull);
      expect(got!.map((p) => p.id).toList(), ['a', 'b']);
      expect(got.first.name, 'Gym A');
      expect(got.first.type, FacilityType.gym);
    });

    test('a cold cache misses (null)', () async {
      final cache = PlacesCache();
      expect(await cache.get(3.1, 101.7, 1500), isNull);
    });
  });

  group('coarse key bucketing (~110 m)', () {
    test('a tiny pan rounds to the same 3-dp bucket → hit', () async {
      final cache = PlacesCache();
      await cache.put(3.10000, 101.70000, 1500, [place('a', 'A')]);
      // <0.0005° drift rounds to the same key.
      expect(await cache.get(3.10004, 101.69996, 1500), isNotNull);
    });

    test('a different area misses', () async {
      final cache = PlacesCache();
      await cache.put(3.100, 101.700, 1500, [place('a', 'A')]);
      expect(await cache.get(3.200, 101.800, 1500), isNull);
    });

    test('the same spot at a different radius is a separate key → miss',
        () async {
      final cache = PlacesCache();
      await cache.put(3.100, 101.700, 1500, [place('a', 'A')]);
      expect(await cache.get(3.100, 101.700, 3000), isNull);
    });
  });

  group('capacity cap (max 12 buckets)', () {
    test('storing 13 areas evicts exactly one (the oldest)', () async {
      final cache = PlacesCache();
      // 13 distinct areas (0.01° apart → distinct 3-dp keys).
      for (var i = 0; i < 13; i++) {
        await cache.put(3.0 + i * 0.01, 101.7, 1500, [place('p$i', 'P$i')]);
      }
      var hits = 0;
      for (var i = 0; i < 13; i++) {
        if (await cache.get(3.0 + i * 0.01, 101.7, 1500) != null) hits++;
      }
      expect(hits, 12); // capped — never grows unbounded
    });
  });

  group('last map centre', () {
    test('round-trips the saved camera position', () async {
      final cache = PlacesCache();
      await cache.saveLastCenter(3.139, 101.687);
      final c = await cache.lastCenter();
      expect(c, isNotNull);
      expect(c!.lat, closeTo(3.139, 1e-9));
      expect(c.lng, closeTo(101.687, 1e-9));
    });

    test('returns null before anything is saved', () async {
      final cache = PlacesCache();
      expect(await cache.lastCenter(), isNull);
    });
  });
}
