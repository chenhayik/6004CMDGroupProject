import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_application_group/services/auth_service.dart';
import 'package:mobile_application_group/services/firestore_service.dart';
import 'package:mobile_application_group/views/login/login_view.dart';
import 'package:mobile_application_group/views/onboarding/setup_profile_view.dart';
import 'package:mobile_application_group/views/home/home_page.dart';
import 'package:mobile_application_group/macro/macro_calculator.dart';

class WidgetTree extends StatelessWidget {
  const WidgetTree({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnapshot) {

        // ── Still loading ──
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ── Not logged in ──
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginView();
        }

        // ── uid is taken from authSnapshot.data here ──
        final String uid = authSnapshot.data!.uid;  // ← defined here

        return FutureBuilder(
          future: FirestoreService().getUserProfile(uid),  // ← used here
          builder: (context, profileSnapshot) {

            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // ── No profile → Onboarding ──
            if (!profileSnapshot.hasData || profileSnapshot.data == null) {
              return const SetupProfileView();
            }

            // ── Profile exists → Home ──
            return const HomePage();
          },
        );
      },
    );
  }
}