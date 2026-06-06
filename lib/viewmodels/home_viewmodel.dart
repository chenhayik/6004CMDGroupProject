import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/daily_log_service.dart';

class HomeViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final DailyLogService  _dailyLogService  = DailyLogService();

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
  int steps        = 0;
  int _stepBaseline = -1;
  String stepStatus = 'walking';
  StreamSubscription<StepCount>?         _stepSubscription;
  StreamSubscription<PedestrianStatus>?  _statusSubscription;

  // ── Daily log stream ──
  StreamSubscription<DailyTotals>? _dailyLogSubscription;

  // ── Midnight reset timer ──
  Timer? _midnightTimer;

  // ── Water ──
  double waterLiters = 0.0;

  // ── Insight banner ──
  bool   showInsightBanner = false;
  String insightMessage    = '';

  // ── UI state ──
  bool isLoading = true;

  HomeViewModel() {
    _loadUserData();
    _initPedometer();
    _scheduleMidnightReset();
  }

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
        _buildInsightMessage();
        notifyListeners();
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
    await prefs.setString('step_date', today);
    _stepBaseline = -1;  // forces re-capture on next step event
    steps = 0;
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
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) return;

    _stepSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) async {
        final prefs   = await SharedPreferences.getInstance();
        final today   = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final savedDate = prefs.getString('step_date');

        if (savedDate != today) {
          // New day — reset
          await prefs.setString('step_date', today);
          await prefs.setInt('step_baseline', event.steps);
          _stepBaseline = event.steps;
        }

        if (_stepBaseline == -1) {
          final saved = prefs.getInt('step_baseline');
          if (saved == null) {
            _stepBaseline = event.steps;
            await prefs.setInt('step_baseline', event.steps);
          } else {
            _stepBaseline = saved;
          }
        }

        steps = (event.steps - _stepBaseline).clamp(0, 999999);
        notifyListeners();
      },
      onError: (e) => debugPrint('Step count error: $e'),
    );

    _statusSubscription = Pedometer.pedestrianStatusStream.listen(
          (PedestrianStatus event) {
        stepStatus = event.status;
        notifyListeners();
      },
      onError: (e) => debugPrint('Pedestrian status error: $e'),
    );
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
    await FirebaseAuth.instance.signOut();
  }

  // ─── Dispose ──────────────────────────────────────────────
  @override
  void dispose() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    _dailyLogSubscription?.cancel();
    _midnightTimer?.cancel();
    super.dispose();
  }
}