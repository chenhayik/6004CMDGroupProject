import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/coach_profile.dart';
import '../services/coach_service.dart';

/// Drives the Coach Directory list + specialization filter. One-shot Firestore
/// read on open (the directory isn't realtime-critical); the spec chips filter
/// the loaded list in memory.
class CoachDirectoryViewModel extends ChangeNotifier {
  final CoachService _service = CoachService();

  bool loading = true;
  String? error;
  List<CoachProfile> _all = [];
  final Set<String> specFilter = {};
  bool _disposed = false;

  /// The signed-in user's own profile (so the FAB reads "Edit" vs "Register").
  CoachProfile? myCoach;

  CoachDirectoryViewModel() {
    load();
  }

  bool get isEmpty => _all.isEmpty;

  List<CoachProfile> get coaches {
    if (specFilter.isEmpty) return _all;
    return _all
        .where((c) => c.specializations.any(specFilter.contains))
        .toList();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      _all = await _service.getCoaches();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      // Read our own profile directly rather than scanning the (capped) list —
      // a long-registered coach can sit beyond the 100-doc directory limit.
      myCoach = uid == null ? null : await _service.getMyCoach(uid);
      error = null;
    } catch (e) {
      debugPrint('Coach load error: $e');
      error = 'Could not load coaches.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void toggleSpec(String key) {
    if (!specFilter.remove(key)) specFilter.add(key);
    notifyListeners();
  }

  // load() can resolve after the screen is gone (back navigation) — don't
  // notify a disposed listener.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
