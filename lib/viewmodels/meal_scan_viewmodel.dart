import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/meal_result.dart';
import '../services/gemini_service.dart';
import '../services/image_picker_service.dart';
import '../services/meal_history_service.dart';

enum MealScanState { idle, picking, analysing, success, error }

class MealScanViewModel extends ChangeNotifier {
  final GeminiService      _geminiService  = GeminiService();
  final ImagePickerService _imageService   = ImagePickerService();
  final MealHistoryService _historyService = MealHistoryService();

  MealScanState    scanState        = MealScanState.idle;
  Uint8List?       selectedImageBytes;
  MealResult?      lastResult;
  String?          errorMessage;
  List<MealResult> mealHistory      = [];
  bool             isLoadingHistory = false;
  bool             isSaving         = false;

  MealScanViewModel() {
    loadHistory();
  }

  Future<void> pickFromCamera(BuildContext context) async {
    scanState = MealScanState.picking;
    notifyListeners();
    final bytes = await _imageService.pickFromCamera();
    if (bytes == null) {
      scanState = MealScanState.idle;
      notifyListeners();
      return;
    }
    await _analyseImage(bytes);
  }

  Future<void> pickFromGallery(BuildContext context) async {
    scanState = MealScanState.picking;
    notifyListeners();
    final bytes = await _imageService.pickFromGallery();
    if (bytes == null) {
      scanState = MealScanState.idle;
      notifyListeners();
      return;
    }
    await _analyseImage(bytes);
  }

  Future<void> _analyseImage(Uint8List bytes) async {
    selectedImageBytes = bytes;
    scanState          = MealScanState.analysing;
    errorMessage       = null;
    notifyListeners();

    try {
      final result = await _geminiService.analyzeImage(bytes);
      lastResult = result;
      scanState  = MealScanState.success;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      scanState    = MealScanState.error;
    }
    notifyListeners();
  }

  // ── Save after user edits ──
  Future<bool> confirmAndSave(MealResult editedMeal) async {
    isSaving = true;
    notifyListeners();
    try {
      await _historyService.saveMeal(editedMeal);
      await loadHistory();
      isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      isSaving     = false;
      errorMessage = 'Failed to save: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Manual entry ──
  Future<bool> addManualMeal(MealResult meal) => confirmAndSave(meal);

  // ── Re-log: creates a brand new entry from an existing meal ──
  // Strips the old id/timestamp so Firestore creates a fresh document
  Future<bool> reLogMeal(MealResult existingMeal) async {
    final freshEntry = MealResult(
      // no id — Firestore will auto-generate a new one
      foodName: existingMeal.foodName,
      calories: existingMeal.calories,
      proteinG: existingMeal.proteinG,
      carbsG:   existingMeal.carbsG,
      fatG:     existingMeal.fatG,
      // no loggedAt — toFirestore() uses FieldValue.serverTimestamp()
    );
    return confirmAndSave(freshEntry);
  }

  Future<void> loadHistory() async {
    isLoadingHistory = true;
    notifyListeners();
    mealHistory      = await _historyService.getMealHistory();
    isLoadingHistory = false;
    notifyListeners();
  }

  Future<void> deleteMeal(String mealId) async {
    try {
      await _historyService.deleteMeal(mealId);
      await loadHistory();
    } catch (e) {
      errorMessage = 'Failed to delete meal';
      notifyListeners();
    }
  }

  void reset() {
    scanState          = MealScanState.idle;
    selectedImageBytes = null;
    lastResult         = null;
    errorMessage       = null;
    notifyListeners();
  }
}