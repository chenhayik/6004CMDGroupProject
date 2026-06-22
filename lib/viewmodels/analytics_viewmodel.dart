import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/analytics_range.dart';
import '../models/analytics_summary.dart';
import '../services/analytics_service.dart';

/// Orchestrates Analytics state (§8). No Firestore here — it delegates all
/// reads/aggregation to [AnalyticsService] and caches one summary per range so
/// re-selecting a range is instant.
class AnalyticsViewModel extends ChangeNotifier {
  AnalyticsViewModel({AnalyticsService? service})
      : _service = service ?? AnalyticsService();

  final AnalyticsService _service;

  AnalyticsRange range = AnalyticsRange.week;
  bool isLoading = false;
  String? error;

  /// Selected exercise id for the 1RM line chart.
  String? selectedExerciseId;

  final Map<AnalyticsRange, AnalyticsSummary> _cache = {};

  /// Summary for the active range (null until first load completes).
  AnalyticsSummary? get summary => _cache[range];

  /// The window subtitle, e.g. "16–22 Jun".
  String get windowSubtitle => range.windowSubtitle();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> load({bool force = false}) async {
    final uid = _uid;
    if (uid == null) {
      error = 'Not signed in';
      notifyListeners();
      return;
    }

    // Serve cache instantly; only hit the network when missing or forced.
    if (!force && _cache.containsKey(range)) {
      _ensureSelectedExercise();
      notifyListeners();
      return;
    }

    isLoading = summary == null; // keep showing cached data while refreshing
    error = null;
    notifyListeners();

    try {
      final result =
          await _service.buildSummary(uid: uid, range: range);
      _cache[range] = result;
      _ensureSelectedExercise();
    } catch (e, st) {
      error = 'Could not load your insights.';
      debugPrint('AnalyticsViewModel.load error: $e\n$st');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setRange(AnalyticsRange r) {
    if (r == range) return;
    range = r;
    // Cached → instant; otherwise load() fetches and caches.
    load();
  }

  void selectExercise(String id) {
    selectedExerciseId = id;
    notifyListeners();
  }

  void _ensureSelectedExercise() {
    final s = summary;
    if (s == null) return;
    final ids = s.e1rmByExercise.keys;
    if (ids.isEmpty) {
      selectedExerciseId = null;
    } else if (selectedExerciseId == null ||
        !ids.contains(selectedExerciseId)) {
      selectedExerciseId = ids.first;
    }
  }

  Future<void> retry() => load(force: true);
}
