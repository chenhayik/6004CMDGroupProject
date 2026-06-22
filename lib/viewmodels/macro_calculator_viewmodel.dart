import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';

enum MacroRatio { balanced, highProtein, lowCarb, highCarb }

extension MacroRatioExt on MacroRatio {
  String get label {
    switch (this) {
      case MacroRatio.balanced:    return 'Balanced';
      case MacroRatio.highProtein: return 'High Protein';
      case MacroRatio.lowCarb:     return 'Low Carb';
      case MacroRatio.highCarb:    return 'High Carb';
    }
  }

  (double, double, double) get split {
    switch (this) {
      case MacroRatio.balanced:    return (0.30, 0.40, 0.30);
      case MacroRatio.highProtein: return (0.40, 0.35, 0.25);
      case MacroRatio.lowCarb:     return (0.35, 0.20, 0.45);
      case MacroRatio.highCarb:    return (0.25, 0.50, 0.25);
    }
  }
}

class MacroCalculatorViewModel extends ChangeNotifier {
  final Map<String, dynamic> formData;
  final FirestoreService _firestoreService = FirestoreService();

  // ── State ──
  MacroRatio macroRatio = MacroRatio.balanced;
  bool isLoading = false;
  String? errorMessage;

  // ── Results (late — calculated in constructor) ──
  late int bmr;
  late int tdee;
  late int targetCalories;
  late int proteinG;
  late int carbsG;
  late int fatG;

  /// True when launched from "Edit goal & targets" rather than onboarding.
  bool get isEditMode => formData['editMode'] == true;

  MacroCalculatorViewModel({required this.formData}) {
    // Preselect the user's saved macro ratio when editing.
    final saved = formData['macroRatio']?.toString();
    if (saved != null) {
      macroRatio = MacroRatio.values.firstWhere(
        (r) => r.name == saved,
        orElse: () => MacroRatio.balanced,
      );
    }
    calculateTargets();   // run on init
  }

  // ── Called on init and when macro tab changes ──
  void calculateTargets() {
    final double weight =
        double.tryParse(formData['weight'].toString()) ?? 70.0;
    final double height =
        double.tryParse(formData['height'].toString()) ?? 170.0;
    final double age =
        double.tryParse(formData['age'].toString()) ?? 30.0;
    final String sex =
    formData['biologicalSex'].toString().toLowerCase();
    final String activityStr =
    formData['activityLevel'].toString().toLowerCase();
    final String goal =
    formData['goal'].toString().toLowerCase();

    // Activity multiplier
    double multiplier = 1.2;
    if (activityStr.contains('light'))    multiplier = 1.375;
    if (activityStr.contains('moderate')) multiplier = 1.55;
    if (activityStr.contains('very'))     multiplier = 1.725;
    if (activityStr.contains('extra'))    multiplier = 1.9;

    // BMR (Mifflin-St Jeor)
    final double rawBmr = sex == 'male'
        ? (10 * weight) + (6.25 * height) - (5 * age) + 5
        : (10 * weight) + (6.25 * height) - (5 * age) - 161;

    final double rawTdee = rawBmr * multiplier;

    // Goal adjustment
    double rawTarget = rawTdee;
    if (goal == 'cut')  rawTarget = rawTdee - 500;
    if (goal == 'bulk') rawTarget = rawTdee + 300;

    // Minimum safe calories
    final double minCalories = sex == 'male' ? 1500 : 1200;
    rawTarget = max(rawTarget, minCalories);

    // Macro split
    final (pPct, cPct, fPct) = macroRatio.split;

    bmr            = rawBmr.round();
    tdee           = rawTdee.round();
    targetCalories = rawTarget.round();
    proteinG       = ((rawTarget * pPct) / 4).round();
    carbsG         = ((rawTarget * cPct) / 4).round();
    fatG           = ((rawTarget * fPct) / 9).round();

    notifyListeners();
  }

  // ── Called when user taps a macro tab ──
  void onMacroRatioChanged(MacroRatio ratio) {
    macroRatio = ratio;
    calculateTargets();   // recalculate with new split
  }

  // ── Save to Firestore and return success/failure ──
  Future<bool> completeSetup() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final targets = NutritionTargets(
        bmr: bmr,
        tdee: tdee,
        targetCalories: targetCalories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        macroRatio: macroRatio.name,
      );

      if (isEditMode) {
        // Reassign goal + targets only — don't overwrite the rest of the
        // profile (createdAt, etc.).
        await _firestoreService.updateGoalAndTargets(
            uid, formData['goal'].toString(), targets);
      } else {
        // Onboarding — create the base profile, then save targets.
        final profile = UserProfile(
          uid: uid,
          age: formData['age'],
          biologicalSex: formData['biologicalSex'],
          height: formData['height'],
          weight: formData['weight'],
          activityLevel: formData['activityLevel'],
          goal: formData['goal'],
        );
        await _firestoreService.createUserProfile(profile);
        await _firestoreService.updateNutritionTargets(uid, targets);
      }

      isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      isLoading = false;
      errorMessage = 'Error saving profile. Please try again.';
      notifyListeners();
      return false;
    }
  }
}