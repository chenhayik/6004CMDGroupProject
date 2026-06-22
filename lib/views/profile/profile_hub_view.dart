import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../widget_tree.dart';

/// Profile hub — opened from the top-left avatar on the dashboard (§1).
/// Holds the user's profile summary, targets, and sign-out.
class ProfileHubView extends StatelessWidget {
  const ProfileHubView({super.key});

  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: FutureBuilder<UserProfile?>(
        future: uid == null
            ? Future.value(null)
            : FirestoreService().getUserProfile(uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar + email
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: _green.withValues(alpha: 0.15),
                      child: const Icon(Icons.person,
                          size: 40, color: _green),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.email ?? 'Signed in',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (profile != null) ...[
                _section('Your Stats', [
                  _row('Goal', _titleCase(profile.goal)),
                  _row('Age', '${profile.age}'),
                  _row('Height', '${profile.height.toStringAsFixed(0)} cm'),
                  _row('Weight', '${profile.weight.toStringAsFixed(1)} kg'),
                  _row('Activity', _titleCase(profile.activityLevel)),
                ]),
                const SizedBox(height: 16),
                if (profile.nutritionTargets != null)
                  _section('Daily Targets', [
                    _row('Calories',
                        '${profile.nutritionTargets!.targetCalories} kcal'),
                    _row('Protein', '${profile.nutritionTargets!.proteinG} g'),
                    _row('Carbs', '${profile.nutritionTargets!.carbsG} g'),
                    _row('Fat', '${profile.nutritionTargets!.fatG} g'),
                  ]),
              ],
              const SizedBox(height: 28),

              // Sign out
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const WidgetTree()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Sign Out',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: Colors.black54)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ],
      ),
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);
}
