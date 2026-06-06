import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/meal_result.dart';
import 'daily_log_service.dart';    // ← ADD

class MealHistoryService {
  final FirebaseFirestore  _db             = FirebaseFirestore.instance;
  final DailyLogService    _dailyLogService = DailyLogService();  // ← ADD

  CollectionReference<Map<String, dynamic>> _userMeals() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');
    return _db.collection('users').doc(uid).collection('meal_history');
  }

  // ── Save meal + update daily log in one go ──
  Future<void> saveMeal(MealResult meal) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not logged in');

    try {
      // 1. Save to meal_history
      await _userMeals().add(meal.toFirestore());

      // 2. ← ADD: Increment today's daily totals
      await _dailyLogService.addMealToLog(uid, meal);

      debugPrint('Meal saved and daily log updated: ${meal.foodName}');
    } catch (e) {
      throw Exception('Failed to save meal: $e');
    }
  }

  Future<List<MealResult>> getMealHistory() async {
    try {
      final snapshot = await _userMeals()
          .orderBy('logged_at', descending: true)
          .limit(20)
          .get();
      return snapshot.docs
          .map((doc) => MealResult.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Stream<List<MealResult>> mealHistoryStream() {
    return _userMeals()
        .orderBy('logged_at', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) => MealResult.fromFirestore(d)).toList());
  }

  Future<void> deleteMeal(String mealId) async {
    await _userMeals().doc(mealId).delete();
  }
}