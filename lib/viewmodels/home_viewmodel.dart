import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/daily_log_service.dart';
import '../services/notification_manager.dart';
import '../services/notification_prefs.dart';
import '../services/meal_cache.dart';
import '../services/meal_history_service.dart';
import '../services/meal_planner.dart';

class HomeViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final DailyLogService  _dailyLogService  = DailyLogService();
  final NotificationManager _notifications = NotificationManager();
  final MealCache _mealCache = MealCache();
  final MealHistoryService _mealHistory = MealHistoryService();

  // ── Profile / Targets ──
  UserProfile? userProfile;
  int targetCalories = 0;
  int proteinTarget  = 0;
  int carbsTarget    = 0;
  int fatTarget      = 0;

  // ── Consumed today (driven by Firestore stream) ──
  int consumedCalories = 0;
  int consumedProtein  = 0;
  int consumedCarbs    = 0;
  int consumedFat      = 0;

  // ── Steps ──
  //
  // The hardware step counter (Android TYPE_STEP_COUNTER / iOS CoreMotion)
  // keeps counting even while the app is closed, but it reports a *cumulative*
  // total since the last device reboot. To turn that into "steps today" we
  // persist:
  //   • step_date     — the day these values belong to (yyyy-MM-dd)
  //   • step_baseline  — sensor reading when the current sensor session began
  //   • step_offset    — steps already banked today from earlier sessions
  //                      (e.g. before a reboot, which resets the sensor to 0)
  //   • step_total     — last computed total today (for instant display + reboot recovery)
  //
  //   stepsToday = step_offset + (sensorReading - step_baseline)
  //
  // Keys live in SharedPreferences so the count survives the app being killed.
  static const _kStepDate     = 'step_date';
  static const _kStepBaseline = 'step_baseline';
  static const _kStepOffset   = 'step_offset';
  static const _kStepTotal    = 'step_total';

  int steps        = 0;
  String stepStatus = 'stopped';

  /// Daily step goal used for progress + activity notifications. Loaded from
  /// [NotificationPrefs] (user-editable on the profile page); falls back to the
  /// default until loaded.
  int stepGoal = NotificationPrefs.defaultStepGoal;
  double get stepProgress =>
      stepGoal > 0 ? (steps / stepGoal).clamp(0.0, 1.0) : 0.0;

  /// Reload the step goal from prefs (call after the user edits it).
  Future<void> reloadStepGoal() async {
    stepGoal = await NotificationPrefs.stepGoal();
    notifyListeners();
  }
  StreamSubscription<StepCount>?         _stepSubscription;
  StreamSubscription<PedestrianStatus>?  _statusSubscription;
  Timer? _stepRefreshTimer;

  // Throttle persistence of steps to Firestore (daily_logs) so Analytics can
  // build a per-day steps trend without hammering Firestore.
  DateTime _lastStepPersist = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastPersistedSteps = 0;

  // ── Daily log stream ──
  StreamSubscription<DailyTotals>? _dailyLogSubscription;

  // ── Midnight reset timer ──
  Timer? _midnightTimer;

  // ── Water (driven by the daily_logs stream) ──
  double waterLiters = 0.0;
  static const double waterGoalLitres = 2.5;
  double get waterProgress =>
      (waterLiters / waterGoalLitres).clamp(0.0, 1.0);

  /// Add water (litres) to today's log; the stream reflects the new total.
  Future<void> addWater(double litres) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_water_log_ms', DateTime.now().millisecondsSinceEpoch);
    await _dailyLogService.addWater(uid, litres);
  }

  // ── Insight banner ──
  bool   showInsightBanner = false;
  String insightMessage    = '';

  // ── UI state ──
  bool isLoading = true;

  HomeViewModel() {
    _loadUserData();
    reloadStepGoal();
    _initPedometer();
    _scheduleMidnightReset();
    _notifications.init(); // request permission + lay down daily reminders
    // Re-arm offline meal notifications from cache (reboots drop one-shots).
    MealPlanner().rescheduleFromCacheIfNeeded();
  }

  /// Fire a sample notification so the user can confirm they're enabled.
  Future<void> sendTestNotification() => _notifications.sendTest();

  // ─── Load profile targets ────────────────────────────────
  Future<void> _loadUserData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final profile = await _firestoreService.getUserProfile(uid);
      if (profile != null) {
        userProfile = profile;
        final nutrition = profile.nutritionTargets;
        if (nutrition != null) {
          targetCalories = nutrition.targetCalories;
          proteinTarget  = nutrition.proteinG;
          carbsTarget    = nutrition.carbsG;
          fatTarget      = nutrition.fatG;
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }

    // Start listening to daily log AFTER profile is loaded
    _subscribeDailyLog();

    // Mirror the meal-planner inputs locally so the background isolate can
    // generate the weekly plan without Firestore/auth.
    _saveMealPlanMirror();
  }

  // ─── Mirror targets + recent meals for the offline meal planner ──
  Future<void> _saveMealPlanMirror() async {
    if (targetCalories <= 0) return;
    try {
      final meals = await _mealHistory.getMealHistory();
      final names = meals.map((m) => m.foodName).take(15).toList();
      await _mealCache.saveInputsMirror(
        kcal: targetCalories,
        protein: proteinTarget,
        carbs: carbsTarget,
        fat: fatTarget,
        goal: userProfile?.goal ?? 'maintain',
        recentMeals: names,
      );
    } catch (e) {
      debugPrint('Meal-plan mirror save error: $e');
    }
  }

  // ─── Real-time Firestore stream for consumed macros ──────
  void _subscribeDailyLog() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Cancel any existing subscription first
    _dailyLogSubscription?.cancel();

    _dailyLogSubscription = _dailyLogService.todayStream(uid).listen(
          (totals) {
        consumedCalories = totals.calories;
        consumedProtein  = totals.proteinG;
        consumedCarbs    = totals.carbsG;
        consumedFat      = totals.fatG;
        waterLiters      = totals.waterLitres;
        _buildInsightMessage();
        notifyListeners();

        // Evaluate contextual push notifications against the fresh totals.
        _notifications.evaluate(
          calories: consumedCalories,
          protein: consumedProtein,
          carbs: consumedCarbs,
          fat: consumedFat,
          targetCalories: targetCalories,
          targetProtein: proteinTarget,
          targetCarbs: carbsTarget,
          targetFat: fatTarget,
          waterLitres: waterLiters,
          waterGoalLitres: waterGoalLitres,
        );
      },
      onError: (e) => debugPrint('Daily log stream error: $e'),
    );
  }

  // ─── Midnight reset ──────────────────────────────────────
  void _scheduleMidnightReset() {
    final now       = DateTime.now();
    final midnight  = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = midnight.difference(now);

    _midnightTimer = Timer(timeUntilMidnight, () {
      debugPrint('Midnight reset triggered — re-subscribing daily log');

      // Consumed values will naturally show 0 because the new
      // date key has no document yet in Firestore
      _subscribeDailyLog();

      // Reset step baseline for new day
      _resetStepBaseline();

      // Schedule next midnight reset
      _scheduleMidnightReset();

      notifyListeners();
    });
  }

  Future<void> _resetStepBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString(_kStepDate, today);
    await prefs.setInt(_kStepOffset, 0);
    await prefs.setInt(_kStepTotal, 0);
    await prefs.remove(_kStepBaseline); // forces re-capture on next step event
    steps = 0;
    notifyListeners();
  }

  // ─── Insight message ─────────────────────────────────────
  void _buildInsightMessage() {
    final proteinLeft = proteinTarget - consumedProtein;
    final carbsOver   = consumedCarbs - carbsTarget;
    final fatLeft     = fatTarget - consumedFat;

    if (proteinLeft > 50) {
      showInsightBanner = true;
      insightMessage =
      "You're ${proteinLeft}g below your protein goal — try a scoop of whey!";
    } else if (carbsOver > 0) {
      showInsightBanner = true;
      insightMessage =
      "You've exceeded your carb goal by ${carbsOver}g today.";
    } else if (fatLeft < 10 && fatLeft >= 0) {
      showInsightBanner = true;
      insightMessage = "You're almost at your fat limit for today. Stay mindful!";
    } else {
      showInsightBanner = false;
      insightMessage = '';
    }
  }

  void dismissInsightBanner() {
    showInsightBanner = false;
    notifyListeners();
  }

  // ─── Pedometer ───────────────────────────────────────────
  Future<void> _initPedometer() async {
    // Show the last saved total immediately so the UI isn't stuck at 0 while
    // we wait for the first sensor event (the hardware kept counting while the
    // app was closed, but we still need a reading to reconcile).
    await _loadPersistedSteps();

    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) return;

    _listenToStepCount();

    // The hardware step counter batches its events, so the live stream can lag
    // by minutes while the app is open. Re-subscribing forces the sensor to
    // emit its current reading immediately, so we poll on a short timer to keep
    // the dashboard updating on its own (no app restart needed).
    _stepRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _listenToStepCount(),
    );

    // pedestrianStatusStream can error on devices without a step sensor (e.g.
    // emulators). Its platform error escapes the stream handler, so the
    // app-level zone guard in main() catches it; this onError covers the rest.
    _statusSubscription = Pedometer.pedestrianStatusStream.listen(
      (PedestrianStatus event) {
        stepStatus = event.status;
        notifyListeners();
      },
      onError: (e) => debugPrint('Pedestrian status error: $e'),
      cancelOnError: false,
    );
  }

  void _listenToStepCount() {
    _stepSubscription?.cancel();
    _stepSubscription = Pedometer.stepCountStream.listen(
      _handleStepCount,
      onError: (e) {
        debugPrint('Step count error: $e');
        // No step sensor on this device — stop the re-subscribe poll so we
        // don't churn / spam errors every few seconds.
        _stepRefreshTimer?.cancel();
        _stepRefreshTimer = null;
        if (stepStatus != 'unavailable') {
          stepStatus = 'unavailable';
          notifyListeners();
        }
      },
      cancelOnError: false,
    );
  }

  // Restore today's total from disk for instant display on launch.
  Future<void> _loadPersistedSteps() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString(_kStepDate) == today) {
      steps = prefs.getInt(_kStepTotal) ?? 0;
      notifyListeners();
    }
  }

  // Reconcile a cumulative sensor reading into "steps today", surviving both
  // the app being closed (the reading jumps forward) and device reboots (the
  // reading drops back toward 0).
  Future<void> _handleStepCount(StepCount event) async {
    final prefs   = await SharedPreferences.getInstance();
    final today   = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final reading = event.steps;

    // ── New day: start a fresh count anchored to the current reading ──
    if (prefs.getString(_kStepDate) != today) {
      await prefs.setString(_kStepDate, today);
      await prefs.setInt(_kStepBaseline, reading);
      await prefs.setInt(_kStepOffset, 0);
      await prefs.setInt(_kStepTotal, 0);
      steps = 0;
      notifyListeners();
      return;
    }

    int baseline = prefs.getInt(_kStepBaseline) ?? -1;
    int offset   = prefs.getInt(_kStepOffset) ?? 0;

    // First reading of a new sensor session today (app start / no baseline yet).
    if (baseline < 0) {
      baseline = reading;
      await prefs.setInt(_kStepBaseline, baseline);
    }

    // ── Reboot (or sensor reset): reading fell below the session baseline ──
    // Bank whatever we'd already counted today, then re-anchor to the new low
    // reading so steps taken before the reboot aren't lost.
    if (reading < baseline) {
      offset = prefs.getInt(_kStepTotal) ?? offset;
      baseline = reading;
      await prefs.setInt(_kStepOffset, offset);
      await prefs.setInt(_kStepBaseline, baseline);
    }

    final total = (offset + (reading - baseline)).clamp(0, 999999);
    await prefs.setInt(_kStepTotal, total);

    steps = total;
    notifyListeners();
    _persistStepsThrottled();
  }

  // Persist today's step count to the daily_log (throttled): at most once per
  // 60s and only on a meaningful change, so Analytics can read `steps_net`.
  void _persistStepsThrottled() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final movedEnough = (steps - _lastPersistedSteps).abs() >= 50;
    final dueByTime = now.difference(_lastStepPersist).inSeconds >= 60;
    if (!movedEnough && !dueByTime) return;

    _lastStepPersist = now;
    _lastPersistedSteps = steps;
    _dailyLogService.updateActivity(uid, stepsNet: steps).catchError(
          (e) => debugPrint('Persist steps error: $e'),
        );

    // Evaluate activity notifications against the fresh step total (shares the
    // same throttle so we don't re-check on every sensor event).
    _notifications.evaluateActivity(steps: steps, stepGoal: stepGoal);
  }

  // ─── Computed getters ────────────────────────────────────
  double get calorieProgress => targetCalories > 0
      ? (consumedCalories / targetCalories).clamp(0.0, 1.0)
      : 0.0;

  int get caloriesLeft => targetCalories - consumedCalories;

  double get proteinProgress => proteinTarget > 0
      ? (consumedProtein / proteinTarget).clamp(0.0, 1.0)
      : 0.0;

  double get carbsProgress => carbsTarget > 0
      ? (consumedCarbs / carbsTarget).clamp(0.0, 1.0)
      : 0.0;

  double get fatProgress => fatTarget > 0
      ? (consumedFat / fatTarget).clamp(0.0, 1.0)
      : 0.0;

  bool get isFatOnTrack => consumedFat <= fatTarget;

  // ─── Sign out ─────────────────────────────────────────────
  Future<void> signOut() async {
    await AuthService().signOut();
  }

  // ─── Dispose ──────────────────────────────────────────────
  @override
  void dispose() {
    _stepRefreshTimer?.cancel();
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    _dailyLogSubscription?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }
}