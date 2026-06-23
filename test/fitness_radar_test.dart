import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_application_group/models/coach_profile.dart';
import 'package:mobile_application_group/models/fitness_place.dart';

void main() {
  group('FitnessPlace.fromPlacesJson', () {
    Map<String, dynamic> sample(String name) => {
          'id': 'abc123',
          'displayName': {'text': name, 'languageCode': 'en'},
          'location': {'latitude': 3.1, 'longitude': 101.6},
          'currentOpeningHours': {'openNow': true},
          'rating': 4.6,
          'userRatingCount': 215,
          'types': ['gym', 'point_of_interest'],
        };

    test('parses the requested fields', () {
      final p = FitnessPlace.fromPlacesJson(sample('Anytime Fitness'));
      expect(p.id, 'abc123');
      expect(p.name, 'Anytime Fitness');
      expect(p.lat, 3.1);
      expect(p.lng, 101.6);
      expect(p.openNow, true);
      expect(p.rating, 4.6);
      expect(p.userRatingCount, 215);
      expect(p.type, FacilityType.gym);
    });

    test('infers finer facility type from the name', () {
      expect(FitnessPlace.fromPlacesJson(sample('Iron Temple Powerlifting')).type,
          FacilityType.powerlifting);
      expect(FitnessPlace.fromPlacesJson(sample('KL Calisthenics Park')).type,
          FacilityType.calisthenics);
      expect(FitnessPlace.fromPlacesJson(sample('CrossFit Bukit Bintang')).type,
          FacilityType.crossfit);
      expect(FitnessPlace.fromPlacesJson(sample('Muay Thai Combat Gym')).type,
          FacilityType.specialized);
    });

    test('tolerates missing optional fields', () {
      final p = FitnessPlace.fromPlacesJson({
        'id': 'x',
        'displayName': {'text': 'Bare Gym'},
        'location': {'latitude': 1.0, 'longitude': 2.0},
      });
      expect(p.openNow, isNull);
      expect(p.rating, isNull);
      expect(p.userRatingCount, isNull);
    });
  });

  group('FitnessPlace distance + cache', () {
    test('distanceLabel switches metres → km', () {
      final p = FitnessPlace(
          id: '1', name: 'G', lat: 0, lng: 0, type: FacilityType.gym);
      p.distanceMeters = 350;
      expect(p.distanceLabel, '350 m');
      p.distanceMeters = 1500;
      expect(p.distanceLabel, '1.5 km');
      p.distanceMeters = null;
      expect(p.distanceLabel, '');
    });

    test('cache round-trips without loss', () {
      final p = FitnessPlace(
        id: 'id1',
        name: 'Strong Barbell Club',
        lat: 3.14,
        lng: 101.7,
        type: FacilityType.powerlifting,
        openNow: false,
        rating: 4.2,
        userRatingCount: 12,
      );
      final back = FitnessPlace.fromCache(p.toCache());
      expect(back.id, p.id);
      expect(back.name, p.name);
      expect(back.lat, p.lat);
      expect(back.lng, p.lng);
      expect(back.type, FacilityType.powerlifting);
      expect(back.openNow, false);
      expect(back.rating, 4.2);
      expect(back.userRatingCount, 12);
    });
  });

  group('CoachProfile.fromMap', () {
    test('parses a full document', () {
      final c = CoachProfile.fromMap('uid9', {
        'uid': 'uid9',
        'displayName': 'Coach Aisyah',
        'specializations': ['weight_loss', 'nutrition'],
        'hourlyRateMyr': 90,
        'availability': 'Weekday evenings',
        'bio': 'NASM certified.',
        'contactMethod': 'phone',
        'contactValue': '0123456789',
        'city': 'Petaling Jaya',
      });
      expect(c.displayName, 'Coach Aisyah');
      expect(c.specializations, ['weight_loss', 'nutrition']);
      expect(c.hourlyRateMyr, 90);
      expect(c.contactMethod, ContactMethod.phone);
      expect(c.city, 'Petaling Jaya');
    });

    test('falls back safely on bad/missing fields', () {
      final c = CoachProfile.fromMap('uid', {'contactMethod': 'carrier_pigeon'});
      expect(c.displayName, 'Coach');
      expect(c.hourlyRateMyr, 0);
      expect(c.specializations, isEmpty);
      expect(c.contactMethod, ContactMethod.whatsapp); // default
    });

    test('specialization labels map to display strings', () {
      expect(CoachSpecializations.label('weight_loss'), 'Weight Loss');
      expect(CoachSpecializations.label('unknown_key'), 'unknown_key');
    });
  });
}
