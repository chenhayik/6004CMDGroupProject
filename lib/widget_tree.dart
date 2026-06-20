import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_application_group/models/user_profile.dart';
import 'package:mobile_application_group/services/auth_service.dart';
import 'package:mobile_application_group/services/firestore_service.dart';
import 'package:mobile_application_group/views/login/login_view.dart';
import 'package:mobile_application_group/views/onboarding/setup_profile_view.dart';
import 'package:mobile_application_group/views/home/home_view.dart';


class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  // Created once, not per build, so we don't spin up a new auth stream
  // subscription on every rebuild.
  final AuthService _authService = AuthService();
  late final Stream<User?> _authStream = _authService.authStateChanges;

  // Cache the profile lookup per uid so a rebuild (e.g. after email
  // verification) doesn't trigger a redundant Firestore read.
  String? _cachedUid;
  Future<UserProfile?>? _profileFuture;

  Future<UserProfile?> _profileFor(String uid) {
    if (_cachedUid != uid || _profileFuture == null) {
      _cachedUid = uid;
      _profileFuture = FirestoreService().getUserProfile(uid);
    }
    return _profileFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
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

        final User user = authSnapshot.data!;
        final String uid = user.uid;

        return FutureBuilder(
          future: _profileFor(uid),
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
            return const HomeView();
          },
        );
      },
    );
  }
}
