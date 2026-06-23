import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/coach_profile.dart';

/// External-intent helpers for the Radar feature (directions + coach contact).
/// Reuses url_launcher (already a project dependency) so no new packages.
class RadarLaunchers {
  /// Opens Google Maps directions to the given point. The https form is handled
  /// by the existing `<data android:scheme="https"/>` manifest query.
  static Future<void> directions(
      BuildContext context, double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    await _launch(context, uri, 'Could not open Maps.');
  }

  /// Opens the right contact channel for a coach (WhatsApp / dialer / email).
  static Future<void> contactCoach(
      BuildContext context, CoachProfile coach) async {
    final value = coach.contactValue.trim();
    if (value.isEmpty) {
      _toast(context, 'This coach has no contact details.');
      return;
    }
    late final Uri uri;
    switch (coach.contactMethod) {
      case ContactMethod.whatsapp:
        final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
        uri = Uri.parse('https://wa.me/$digits'
            '?text=${Uri.encodeComponent('Hi ${coach.displayName}, '
            "I'd like to ask about your coaching.")}');
        break;
      case ContactMethod.phone:
        uri = Uri(scheme: 'tel', path: value);
        break;
      case ContactMethod.email:
        uri = Uri(
          scheme: 'mailto',
          path: value,
          query: 'subject=${Uri.encodeComponent('Coaching enquiry')}',
        );
        break;
    }
    await _launch(context, uri, 'Could not open ${coach.contactMethod.label}.');
  }

  static Future<void> _launch(
      BuildContext context, Uri uri, String onError) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _toast(context, onError);
    } catch (_) {
      if (context.mounted) _toast(context, onError);
    }
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
