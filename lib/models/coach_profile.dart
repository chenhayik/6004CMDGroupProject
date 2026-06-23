import 'package:cloud_firestore/cloud_firestore.dart';

/// How a coach prefers to be contacted; drives the "Inquire" button intent.
enum ContactMethod { whatsapp, phone, email }

extension ContactMethodInfo on ContactMethod {
  String get label {
    switch (this) {
      case ContactMethod.whatsapp:
        return 'WhatsApp';
      case ContactMethod.phone:
        return 'Phone';
      case ContactMethod.email:
        return 'Email';
    }
  }
}

/// A locally-registered personal trainer. Stored at `coaches/{uid}` — one doc
/// per trainer, the trainer being the signed-in user who created it.
class CoachProfile {
  final String uid;
  final String displayName;
  final List<String> specializations; // e.g. weight_loss, powerlifting
  final int hourlyRateMyr;
  final String availability; // free-text summary, e.g. "Weekday evenings"
  final String bio;
  final ContactMethod contactMethod;
  final String contactValue;
  final String city;

  CoachProfile({
    required this.uid,
    required this.displayName,
    required this.specializations,
    required this.hourlyRateMyr,
    required this.availability,
    required this.bio,
    required this.contactMethod,
    required this.contactValue,
    required this.city,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'displayName': displayName,
        'specializations': specializations,
        'hourlyRateMyr': hourlyRateMyr,
        'availability': availability,
        'bio': bio,
        'contactMethod': contactMethod.name,
        'contactValue': contactValue,
        'city': city,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory CoachProfile.fromMap(String uid, Map<String, dynamic> m) =>
      CoachProfile(
        uid: uid,
        displayName: m['displayName'] as String? ?? 'Coach',
        specializations:
            (m['specializations'] as List?)?.map((e) => '$e').toList() ??
                const [],
        hourlyRateMyr: (m['hourlyRateMyr'] as num?)?.toInt() ?? 0,
        availability: m['availability'] as String? ?? '',
        bio: m['bio'] as String? ?? '',
        contactMethod: ContactMethod.values.firstWhere(
          (c) => c.name == m['contactMethod'],
          orElse: () => ContactMethod.whatsapp,
        ),
        contactValue: m['contactValue'] as String? ?? '',
        city: m['city'] as String? ?? '',
      );
}

/// The fixed specialization vocabulary, shared by the filter chips and the
/// registration form so stored values stay consistent.
class CoachSpecializations {
  static const Map<String, String> all = {
    'weight_loss': 'Weight Loss',
    'powerlifting': 'Powerlifting',
    'bodybuilding': 'Bodybuilding',
    'calisthenics': 'Calisthenics',
    'crossfit': 'CrossFit',
    'mobility': 'Mobility',
    'nutrition': 'Nutrition',
  };

  static String label(String key) => all[key] ?? key;
}
