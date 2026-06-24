import 'package:flutter/material.dart';

import '../../services/notification_manager.dart';
import '../../services/notification_prefs.dart';

/// Per-category toggles for the notification system. Changes are persisted to
/// [NotificationPrefs] and applied immediately via [NotificationManager] so the
/// fixed daily reminders are scheduled/cancelled as the user flips switches.
class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  State<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF8FAFC);

  final NotificationManager _notifications = NotificationManager();

  bool _food = true;
  bool _hydration = true;
  bool _activity = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final food = await NotificationPrefs.foodEnabled();
    final hydration = await NotificationPrefs.hydrationEnabled();
    final activity = await NotificationPrefs.activityEnabled();
    if (!mounted) return;
    setState(() {
      _food = food;
      _hydration = hydration;
      _activity = activity;
      _loading = false;
    });
  }

  Future<void> _setFood(bool v) async {
    setState(() => _food = v);
    await NotificationPrefs.setFoodEnabled(v);
    await _notifications.applyScheduledReminders();
  }

  Future<void> _setHydration(bool v) async {
    setState(() => _hydration = v);
    await NotificationPrefs.setHydrationEnabled(v);
    await _notifications.applyScheduledReminders();
  }

  Future<void> _setActivity(bool v) async {
    setState(() => _activity = v);
    await NotificationPrefs.setActivityEnabled(v);
    await _notifications.applyScheduledReminders();
  }

  Future<void> _sendTest() async {
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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Notifications',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(children: [
                  _toggle(
                    icon: Icons.restaurant,
                    title: 'Food & nutrition',
                    subtitle:
                        'Calorie surplus, protein, goal hit & skipped-meal alerts.',
                    value: _food,
                    onChanged: _setFood,
                  ),
                  const Divider(height: 1),
                  _toggle(
                    icon: Icons.water_drop_outlined,
                    title: 'Hydration',
                    subtitle: 'Daytime reminders and a nudge when you fall behind.',
                    value: _hydration,
                    onChanged: _setHydration,
                  ),
                  const Divider(height: 1),
                  _toggle(
                    icon: Icons.directions_walk,
                    title: 'Activity',
                    subtitle:
                        '“Get moving” reminders and your daily step-goal updates.',
                    value: _activity,
                    onChanged: _setActivity,
                  ),
                ]),
                const SizedBox(height: 20),
                _testButton(),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Turning a category off cancels its scheduled reminders and '
                    'silences its alerts. You can turn it back on anytime.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      activeColor: _green,
      secondary: Icon(icon, color: _green),
      title: Text(title,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _testButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _sendTest,
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

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }
}
