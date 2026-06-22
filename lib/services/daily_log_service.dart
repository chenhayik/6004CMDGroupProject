import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/meal_result.dart';

class DailyLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Today's date string e.g. "2026-05-27" ──
  String get _todayKey =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  // ── Reference to today's document ──
  DocumentReference<Map<String, dynamic>> _todayRef(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('daily_logs')
        .doc(_todayKey);
  }

  // ── Add meal macros to today's running totals ──
  Future<void> addMealToLog(String uid, MealResult meal) async {
    await _todayRef(uid).set(
      {
        'consumed_calories': FieldValue.increment(meal.calories),
        'consumed_protein_g': FieldValue.increment(meal.proteinG),
        'consumed_carbs_g': FieldValue.increment(meal.carbsG),
        'consumed_fat_g': FieldValue.increment(meal.fatG),
        'date': _todayKey,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),   // merge so first meal creates the doc
    );
  }

  // ── Persist today's activity (steps / water) so Analytics can build a
  //    historical trend. Merged into the same daily_logs doc. ──
  Future<void> updateActivity(
    String uid, {
    int? stepsNet,
    double? waterLiters,
  }) async {
    final data = <String, dynamic>{
      'date': _todayKey,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (stepsNet != null) data['steps_net'] = stepsNet;
    if (waterLiters != null) data['water_liters'] = waterLiters;

    await _todayRef(uid).set(data, SetOptions(merge: true));
  }

  // ── Add water (litres) to today's running total. ──
  Future<void> addWater(String uid, double litres) async {
    await _todayRef(uid).set(
      {
        'water_liters': FieldValue.increment(litres),
        'water_updated_at': FieldValue.serverTimestamp(),
        'date': _todayKey,
        'updated_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ── Real-time stream of today's consumed totals ──
  Stream<DailyTotals> todayStream(String uid) {
    return _todayRef(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return DailyTotals.zero();
      }
      return DailyTotals.fromMap(doc.data()!);
    });
  }

  // ── One-time fetch ──
  Future<DailyTotals> getTodayTotals(String uid) async {
    final doc = await _todayRef(uid).get();
    if (!doc.exists || doc.data() == null) return DailyTotals.zero();
    return DailyTotals.fromMap(doc.data()!);
  }
}

// ── Simple data class for daily consumed values ──
class DailyTotals {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final double waterLitres;

  const DailyTotals({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.waterLitres = 0.0,
  });

  factory DailyTotals.zero() => const DailyTotals(
    calories: 0,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    waterLitres: 0.0,
  );

  factory DailyTotals.fromMap(Map<String, dynamic> map) {
    return DailyTotals(
      calories: _parseInt(map['consumed_calories']),
      proteinG: _parseInt(map['consumed_protein_g']),
      carbsG:   _parseInt(map['consumed_carbs_g']),
      fatG:     _parseInt(map['consumed_fat_g']),
      waterLitres: _parseDouble(map['water_liters']),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}