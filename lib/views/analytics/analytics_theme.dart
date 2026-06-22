import 'package:flutter/material.dart';

/// Design tokens for Analytics (§7). A metric uses the SAME colour in its
/// card and its chart.
class AnalyticsColors {
  AnalyticsColors._();

  static const calories = Color(0xFF27A567); // brand / steps
  static const protein = Color(0xFF3B82F6);
  static const carbs = Color(0xFFF59E0B);
  static const fat = Color(0xFFEC4899);
  static const water = Color(0xFF38BDF8);
  static const volume = Color(0xFF1E8E6B); // training volume
  static const targetLine = Color(0xFF9CA3AF); // dashed goal line

  static const positive = Color(0xFF16A34A);
  static const negative = Color(0xFFEF4444);

  static const bg = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const border = Color(0xFFE5E7EB);
  static const muted = Color(0xFF64748B);
  static const ink = Color(0xFF0F172A);
}
