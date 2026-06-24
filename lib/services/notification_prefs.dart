import 'package:shared_preferences/shared_preferences.dart';

/// Device-side preferences for the notification system: per-category on/off
/// switches and the daily step goal. Backed by SharedPreferences so the
/// settings survive restarts and can be read from both the UI and the
/// [NotificationManager] without Firestore.
///
/// All categories default to ENABLED so existing users keep their current
/// behaviour until they opt out.
class NotificationPrefs {
  NotificationPrefs._();

  static const _kFood = 'notif_food_enabled';
  static const _kHydration = 'notif_hydration_enabled';
  static const _kActivity = 'notif_activity_enabled';
  static const _kStepGoal = 'daily_step_goal';

  /// Fallback step goal when the user hasn't set one.
  static const int defaultStepGoal = 10000;

  static Future<bool> _flag(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true; // default: enabled
  }

  static Future<void> _setFlag(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<bool> foodEnabled() => _flag(_kFood);
  static Future<bool> hydrationEnabled() => _flag(_kHydration);
  static Future<bool> activityEnabled() => _flag(_kActivity);

  static Future<void> setFoodEnabled(bool v) => _setFlag(_kFood, v);
  static Future<void> setHydrationEnabled(bool v) => _setFlag(_kHydration, v);
  static Future<void> setActivityEnabled(bool v) => _setFlag(_kActivity, v);

  /// Daily step goal (always a sane positive value).
  static Future<int> stepGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kStepGoal) ?? defaultStepGoal;
    return v <= 0 ? defaultStepGoal : v;
  }

  static Future<void> setStepGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStepGoal, goal.clamp(1000, 100000));
  }
}
