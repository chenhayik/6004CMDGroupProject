import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class HomeViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // ── Profile / Nutrition data ──
  UserProfile? userProfile;
  int targetCalories = 0;
  int consumedCalories = 0;
  int proteinTarget = 0;
  int carbsTarget = 0;
  int fatTarget = 0;
  int consumedProtein = 0;
  int consumedCarbs = 0;
  int consumedFat = 0;

  // ── Step counter ──
  int steps = 0;
  int _stepBaseline = -1;
  String stepStatus = 'walking'; // 'walking' or 'stopped'
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  // ── Water ──
  double waterLiters = 0.0;

  // ── Insight banner ──
  bool showInsightBanner = true;
  String insightMessage = '';

  // ── UI state ──
  bool isLoading = true;

  HomeViewModel() {
    _loadUserData();
    _initPedometer();
  }

  // ── Load profile + nutrition targets from Firestore ──
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

        _buildInsightMessage();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Build smart insight based on macros ──
  void _buildInsightMessage() {
    final proteinLeft = proteinTarget - consumedProtein;
    final carbsLeft   = carbsTarget - consumedCarbs;
    final fatLeft     = fatTarget - consumedFat;

    if (proteinLeft > 50) {
      insightMessage =
      "You're ${proteinLeft}g below your protein goal — try a scoop of whey!";
    } else if (carbsLeft < 0) {
      insightMessage =
      "You've exceeded your carb goal by ${carbsLeft.abs()}g today.";
    } else if (fatLeft < 10 && fatLeft >= 0) {
      insightMessage = "You're almost at your fat limit for today. Stay mindful!";
    } else {
      insightMessage = "You're on track today. Keep it up!";
      showInsightBanner = false; // hide if no actionable insight
    }
  }

  void dismissInsightBanner() {
    showInsightBanner = false;
    notifyListeners();
  }

  // ── Pedometer ──
  Future<void> _initPedometer() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) return;

    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final savedDate = prefs.getString('step_date');

    _stepSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) async {
        final prefs = await SharedPreferences.getInstance();

        // ── New day → reset baseline ──
        if (savedDate != today) {
          await prefs.setString('step_date', today);
          await prefs.setInt('step_baseline', event.steps);
          _stepBaseline = event.steps;
        }

        // ── Same day → use saved baseline ──
        if (_stepBaseline == -1) {
          _stepBaseline = prefs.getInt('step_baseline') ?? event.steps;
          // If no saved baseline for today, save it now
          if (prefs.getInt('step_baseline') == null) {
            await prefs.setInt('step_baseline', event.steps);
          }
        }

        steps = (event.steps - _stepBaseline).clamp(0, 999999);
        notifyListeners();
      },
      onError: (error) => debugPrint('Step count error: $error'),
    );

    _statusSubscription = Pedometer.pedestrianStatusStream.listen(
          (PedestrianStatus event) {
        stepStatus = event.status;
        notifyListeners();
      },
      onError: (error) => debugPrint('Pedestrian status error: $error'),
    );
  }

  // ── Computed getters ──
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

  // ── Sign out ──
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}