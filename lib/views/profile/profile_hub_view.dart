import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../models/user_profile.dart';
import '../../models/weight_entry.dart';
import '../../models/trend_point.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/weight_service.dart';
import '../../services/notification_manager.dart';
import '../../services/notification_prefs.dart';
import '../../widget_tree.dart';
import '../onboarding/select_goal_view.dart';
import '../analytics/widgets/trend_line_chart.dart';
import 'notification_settings_view.dart';

/// Profile hub — opened from the top-left avatar (§1). Holds the profile
/// summary, daily targets, goal reassignment, body-weight logging + trend,
/// and sign-out.
class ProfileHubView extends StatefulWidget {
  const ProfileHubView({super.key});

  @override
  State<ProfileHubView> createState() => _ProfileHubViewState();
}

class _ProfileHubViewState extends State<ProfileHubView> {
  static const _green = Color(0xFF22C55E);
  static const _weightColor = Color(0xFF6366F1);
  static const _bg = Color(0xFFF8FAFC);

  final FirestoreService _firestore = FirestoreService();
  final WeightService _weightService = WeightService();
  final NotificationManager _notifications = NotificationManager();

  UserProfile? _profile;
  List<WeightEntry> _weights = const [];
  int _stepGoal = NotificationPrefs.defaultStepGoal;
  bool _loading = true;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final profile = await _firestore.getUserProfile(uid);
      final weights = await _weightService.history(uid);
      final stepGoal = await NotificationPrefs.stepGoal();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _weights = weights;
        _stepGoal = stepGoal;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Goal reassignment ───────────────────────────────────
  void _editGoal() {
    final p = _profile;
    if (p == null) return;
    final formData = <String, dynamic>{
      'age': p.age,
      'biologicalSex': p.biologicalSex,
      'height': p.height,
      'weight': p.weight,
      'activityLevel': p.activityLevel,
      'goal': p.goal,
      'macroRatio': p.nutritionTargets?.macroRatio,
      'editMode': true,
    };
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SelectGoalView(formData: formData)),
    );
  }

  // ─── Weight logging ──────────────────────────────────────
  Future<void> _logWeight() async {
    final controller = TextEditingController(
      text: _profile?.weight.toStringAsFixed(1),
    );
    final kg = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            suffixText: 'kg',
            hintText: 'e.g. 78.5',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v >= 20 && v <= 500) {
                Navigator.pop(ctx, v);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (kg == null) return;
    final uid = _uid;
    if (uid == null) return;
    await _weightService.logWeight(uid, kg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged ${kg.toStringAsFixed(1)} kg')),
    );
    _load(); // refresh current weight + trend
  }

  // ─── Step goal ───────────────────────────────────────────
  Future<void> _editStepGoal() async {
    final controller = TextEditingController(text: '$_stepGoal');
    final goal = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily step goal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: 'steps',
            hintText: 'e.g. 10000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v != null && v >= 1000 && v <= 100000) {
                Navigator.pop(ctx, v);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (goal == null) return;
    await NotificationPrefs.setStepGoal(goal);
    if (!mounted) return;
    setState(() => _stepGoal = goal);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Step goal set to ${_formatInt(goal)} steps')),
    );
  }

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingsView()),
    );
  }

  Future<void> _sendTestNotification() async {
    await _notifications.sendTest();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test notification sent — check your shade.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final profile = _profile;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Profile',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar + email
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: _green.withValues(alpha: 0.15),
                        child:
                            const Icon(Icons.person, size: 40, color: _green),
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

                if (profile != null) ...[
                  _statsCard(profile),
                  const SizedBox(height: 16),
                  if (profile.nutritionTargets != null) ...[
                    _targetsCard(profile),
                    const SizedBox(height: 16),
                  ],
                  _weightCard(profile),
                  const SizedBox(height: 16),
                ],

                _stepGoalCard(),
                const SizedBox(height: 16),
                _notificationSettingsButton(),
                const SizedBox(height: 12),
                _testNotificationButton(),
                const SizedBox(height: 12),
                _signOutButton(),
              ],
            ),
    );
  }

  // ─── Stats + goal ────────────────────────────────────────
  Widget _statsCard(UserProfile profile) {
    return _card(
      title: 'Your Stats',
      trailing: TextButton.icon(
        onPressed: _editGoal,
        icon: const Icon(Icons.tune, size: 16, color: _green),
        label: const Text('Edit goal',
            style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      children: [
        _row('Goal', _titleCase(profile.goal)),
        _row('Age', '${profile.age}'),
        _row('Height', '${profile.height.toStringAsFixed(0)} cm'),
        _row('Weight', '${profile.weight.toStringAsFixed(1)} kg'),
        _row('Activity', _titleCase(profile.activityLevel)),
      ],
    );
  }

  Widget _targetsCard(UserProfile profile) {
    final t = profile.nutritionTargets!;
    return _card(
      title: 'Daily Targets',
      children: [
        _row('Calories', '${t.targetCalories} kcal'),
        _row('Protein', '${t.proteinG} g'),
        _row('Carbs', '${t.carbsG} g'),
        _row('Fat', '${t.fatG} g'),
      ],
    );
  }

  Widget _stepGoalCard() {
    return _card(
      title: 'Activity Goal',
      trailing: TextButton.icon(
        onPressed: _editStepGoal,
        icon: const Icon(Icons.tune, size: 16, color: _green),
        label: const Text('Edit',
            style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      children: [
        _row('Daily steps', '${_formatInt(_stepGoal)} steps'),
      ],
    );
  }

  // ─── Weight section ──────────────────────────────────────
  Widget _weightCard(UserProfile profile) {
    final hasTrend = _weights.length >= 2;
    final delta = hasTrend
        ? _weights.last.weightKg - _weights.first.weightKg
        : null;

    return _card(
      title: 'Body Weight',
      trailing: TextButton.icon(
        onPressed: _logWeight,
        icon: const Icon(Icons.add, size: 16, color: _weightColor),
        label: const Text('Log',
            style:
                TextStyle(color: _weightColor, fontWeight: FontWeight.w600)),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${profile.weight.toStringAsFixed(1)} kg',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            if (delta != null)
              Text(
                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: delta > 0
                      ? const Color(0xFFEF4444)
                      : (delta < 0 ? _green : Colors.black45),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_weights.isEmpty)
          const Text(
            'No weight logged yet. Tap “Log” to start tracking.',
            style: TextStyle(fontSize: 12.5, color: Colors.black54),
          )
        else
          SizedBox(
            height: 150,
            child: TrendLineChart(
              points: _weights
                  .map((e) => TrendPoint(
                        label: DateFormat('d/M').format(e.date),
                        date: e.date,
                        value: e.weightKg,
                      ))
                  .toList(),
              color: _weightColor,
              unit: 'kg',
            ),
          ),
      ],
    );
  }

  Widget _notificationSettingsButton() {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openNotificationSettings,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: const [
                Icon(Icons.notifications_outlined, color: _green),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Notification settings',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87)),
                ),
                Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _testNotificationButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _sendTestNotification,
        icon: const Icon(Icons.notifications_active_outlined, color: _green),
        label: const Text('Send test notification',
            style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _green),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _signOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () async {
          await AuthService().signOut(); // Firebase + Google
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const WidgetTree()),
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ─── Shared bits ─────────────────────────────────────────
  Widget _card({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
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

  static String _formatInt(int n) => NumberFormat('#,###').format(n);
}
