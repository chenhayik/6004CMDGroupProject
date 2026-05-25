import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';

class SetupProfileViewModel extends ChangeNotifier {
  final _firestoreService = FirestoreService();

  // ── Controllers ──
  final TextEditingController ageController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  // ── Dropdown state ──
  String? selectedSex;
  String? selectedActivityLevel;
  bool isLoading = false;
  String? errorMessage;

  // ── Options ──
  final List<String> sexOptions = ['Male', 'Female'];
  final List<String> activityOptions = [
    'Sedentary (little or no exercise)',
    'Lightly active (1–3 days/week)',
    'Moderately active (3–5 days/week)',
    'Very active (6–7 days/week)',
    'Extra active (physical job)',
  ];

  void onSexChanged(String? value) {
    selectedSex = value;
    notifyListeners();
  }

  void onActivityChanged(String? value) {
    selectedActivityLevel = value;
    notifyListeners();
  }

  // ── Validators ──
  String? validateAge(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your age';
    final age = int.tryParse(value);
    if (age == null || age < 10 || age > 100) return 'Enter a valid age';
    return null;
  }

  String? validateHeight(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your height';
    final h = double.tryParse(value);
    if (h == null || h < 50 || h > 250) return 'Enter a valid height';
    return null;
  }

  String? validateWeight(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your weight';
    final w = double.tryParse(value);
    if (w == null || w < 20 || w > 300) return 'Enter a valid weight';
    return null;
  }

  String? validateSex(String? value) =>
      value == null ? 'Please select your biological sex' : null;

  String? validateActivity(String? value) =>
      value == null ? 'Please select your activity level' : null;

  // ── Save to Firestore ──
  Future<bool> saveProfile(String goal) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final profile = UserProfile(
        uid: uid,
        age: int.parse(ageController.text.trim()),
        biologicalSex: selectedSex!,
        height: double.parse(heightController.text.trim()),
        weight: double.parse(weightController.text.trim()),
        activityLevel: selectedActivityLevel!,
        goal: goal,
      );

      await _firestoreService.createUserProfile(profile);
      isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      isLoading = false;
      errorMessage = 'Failed to save profile. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ── Pass data to next screen ──
  Map<String, dynamic> collectFormData() => {
    'age': int.parse(ageController.text.trim()),
    'biologicalSex': selectedSex!,
    'height': double.parse(heightController.text.trim()),
    'weight': double.parse(weightController.text.trim()),
    'activityLevel': selectedActivityLevel!,
  };

  @override
  void dispose() {
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }
}