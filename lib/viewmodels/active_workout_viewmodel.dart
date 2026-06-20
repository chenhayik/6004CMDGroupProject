import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../models/routine.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';

class ActiveWorkoutViewModel extends ChangeNotifier {
  final WorkoutService _service = WorkoutService();

  static const _kActiveKey = 'active_workout_v1';

  // ── Session ──
  Workout? workout;
  bool isSaving = false;

  // ── Derived history data ──
  Map<String, List<WorkoutSet>> _previous = {};
  Map<String, ExerciseBest> _bests = {};

  // ── Rest timer ──
  int defaultRestSec = 90;
  bool restActive = false;   // a rest period exists (running or paused)
  bool restPaused = false;   // countdown frozen by the user
  int restRemaining = 0;

  bool get restRunning => restActive && !restPaused;

  Timer? _ticker;

  bool get hasActiveSession => workout != null;

  // ─── Lifecycle ───────────────────────────────────────────────
  /// Loads history (for previous/PR) and restores any in-progress session.
  Future<void> init() async {
    final history = await _service.getHistory(limit: 50);
    _previous = _service.previousByExercise(history);
    _bests = _service.bestsByExercise(history);
    await _restore();
    notifyListeners();
  }

  void startEmpty({String name = 'Workout'}) {
    workout = Workout(name: name, startedAt: DateTime.now());
    _startTicker();
    _persist();
    notifyListeners();
  }

  /// Starts a session pre-loaded from a (recommended) routine: each exercise is
  /// seeded with its target number of sets, pre-filled from the user's previous
  /// performance where available, otherwise from the routine's targets.
  void startFromRoutine(Routine routine) {
    workout = Workout(
      name: routine.name,
      startedAt: DateTime.now(),
      fromRoutineId: routine.id,
    );
    for (final re in routine.exercises) {
      final we = WorkoutExercise(
        exerciseId: re.exerciseId,
        name: re.name,
        type: re.type,
      );
      final count = re.targetSets.clamp(1, 10);
      for (int i = 0; i < count; i++) {
        final s = _prefilledSet(re.exerciseId, re.type, i);
        // Fall back to the routine's targets when there's no history yet.
        if (re.type.needsReps && s.reps == null) s.reps = re.targetReps;
        if (re.type.needsDuration && s.durationSec == null) {
          s.durationSec = re.targetDurationSec;
        }
        we.sets.add(s);
      }
      workout!.exercises.add(we);
    }
    _startTicker();
    _persist();
    notifyListeners();
  }

  // ─── Exercises ───────────────────────────────────────────────
  void addExercise(Exercise exercise) {
    if (workout == null) startEmpty();
    final we = WorkoutExercise(
      exerciseId: exercise.id,
      name: exercise.name,
      type: exercise.type,
    );
    // Seed one set, prefilled from last time if we have it.
    we.sets.add(_prefilledSet(exercise.id, exercise.type, 0));
    workout!.exercises.add(we);
    _persist();
    notifyListeners();
  }

  void removeExercise(int exIndex) {
    workout!.exercises.removeAt(exIndex);
    _persist();
    notifyListeners();
  }

  void addSet(int exIndex) {
    final ex = workout!.exercises[exIndex];
    ex.sets.add(_prefilledSet(ex.exerciseId, ex.type, ex.sets.length));
    _persist();
    notifyListeners();
  }

  void removeSet(int exIndex, int setIndex) {
    workout!.exercises[exIndex].sets.removeAt(setIndex);
    _persist();
    notifyListeners();
  }

  // Build a set pre-filled from the previous performance (or the last logged
  // set), so users only adjust what changed — the progressive-overload prompt.
  WorkoutSet _prefilledSet(String exerciseId, ExerciseType type, int index) {
    final prev = _previous[exerciseId];
    if (prev != null && index < prev.length) {
      return prev[index].copy();
    }
    final existing = workout?.exercises
        .firstWhere((e) => e.exerciseId == exerciseId,
            orElse: () => WorkoutExercise(
                exerciseId: exerciseId, name: '', type: type))
        .sets;
    if (existing != null && existing.isNotEmpty) {
      return existing.last.copy();
    }
    return WorkoutSet();
  }

  /// The previous performance for a given set slot, for the "prev" column.
  WorkoutSet? previousSet(String exerciseId, int setIndex) {
    final prev = _previous[exerciseId];
    if (prev == null || setIndex >= prev.length) return null;
    return prev[setIndex];
  }

  // ─── Editing set fields ──────────────────────────────────────
  void updateSet(
    int exIndex,
    int setIndex, {
    double? weightKg,
    int? reps,
    double? distanceM,
    int? durationSec,
    double? rpe,
    bool clearRpe = false,
  }) {
    final s = workout!.exercises[exIndex].sets[setIndex];
    if (weightKg != null) s.weightKg = weightKg;
    if (reps != null) s.reps = reps;
    if (distanceM != null) s.distanceM = distanceM;
    if (durationSec != null) s.durationSec = durationSec;
    if (clearRpe) {
      s.rpe = null;
    } else if (rpe != null) {
      s.rpe = rpe;
    }
    _persist();
    notifyListeners();
  }

  void setSetType(int exIndex, int setIndex, SetType type) {
    workout!.exercises[exIndex].sets[setIndex].type = type;
    _persist();
    notifyListeners();
  }

  /// Toggle the set's completed checkbox. Completing a working set runs PR
  /// detection. The rest timer is started manually via [toggleRest].
  void toggleComplete(int exIndex, int setIndex) {
    final s = workout!.exercises[exIndex].sets[setIndex];
    s.completed = !s.completed;
    if (s.completed) {
      final exerciseId = workout!.exercises[exIndex].exerciseId;
      _checkPR(exerciseId, s);
    } else {
      s.isPR = false;
    }
    _persist();
    notifyListeners();
  }

  void _checkPR(String exerciseId, WorkoutSet s) {
    if (s.type == SetType.warmup) return;
    final best = _bests.putIfAbsent(exerciseId, () => ExerciseBest());
    bool isPR = false;
    if (s.weightKg != null && s.weightKg! > best.maxWeightKg) {
      best.maxWeightKg = s.weightKg!;
      isPR = true;
    }
    final e1rm = s.estimated1RM();
    if (e1rm != null && e1rm > best.maxEstimated1RM) {
      best.maxEstimated1RM = e1rm;
      isPR = true;
    }
    final vol = s.volume();
    if (vol > best.maxSetVolume) {
      best.maxSetVolume = vol;
      if (vol > 0) isPR = true;
    }
    s.isPR = isPR;
  }

  // ─── Rest timer ──────────────────────────────────────────────
  void startRest(int seconds) {
    restActive = true;
    restPaused = false;
    restRemaining = seconds;
    _startTicker();
    notifyListeners();
  }

  /// Single button control: start the rest timer when idle, otherwise toggle
  /// between running and stopped (paused). Ending the timer is still [skipRest].
  void toggleRest() {
    if (!restActive) {
      startRest(defaultRestSec);
    } else {
      restPaused = !restPaused;
      notifyListeners();
    }
  }

  void addRest(int seconds) {
    restRemaining = (restRemaining + seconds).clamp(0, 3600);
    if (restRemaining > 0) restActive = true;
    notifyListeners();
  }

  void skipRest() {
    restActive = false;
    restPaused = false;
    restRemaining = 0;
    notifyListeners();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      // Only count down while running (not paused).
      if (restRunning && restRemaining > 0) {
        restRemaining--;
        if (restRemaining == 0) restActive = false;
      }
      // Rebuild for the live elapsed-time header and rest countdown.
      notifyListeners();
    });
  }

  // ─── Stats ───────────────────────────────────────────────────
  double get totalVolume => workout?.totalVolumeKg ?? 0;
  int get completedSets => workout?.completedSetCount ?? 0;
  int get elapsedSec => workout?.durationSec ?? 0;

  List<WorkoutSet> get prSetsThisSession =>
      workout?.exercises.expand((e) => e.sets).where((s) => s.isPR).toList() ??
      [];

  // ─── Finish / discard ────────────────────────────────────────
  /// Persists the session and returns it for the summary screen. Returns null
  /// on failure.
  Future<Workout?> finish() async {
    if (workout == null) return null;
    isSaving = true;
    notifyListeners();
    try {
      workout!.finishedAt = DateTime.now();
      // Drop empty exercises (added but never logged).
      workout!.exercises.removeWhere((e) => e.sets.isEmpty);
      await _service.saveWorkout(workout!);
      final finished = workout;
      await _clearPersisted();
      _stop();
      workout = null;
      isSaving = false;
      notifyListeners();
      return finished;
    } catch (e) {
      debugPrint('Failed to save workout: $e');
      isSaving = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> discard() async {
    await _clearPersisted();
    _stop();
    workout = null;
    notifyListeners();
  }

  // ─── Local resume persistence ────────────────────────────────
  Future<void> _persist() async {
    if (workout == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActiveKey, jsonEncode(workout!.toMap()));
    } catch (_) {}
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kActiveKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      workout = Workout.fromMap(null, map);
      _startTicker();
    } catch (_) {}
  }

  Future<void> _clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kActiveKey);
    } catch (_) {}
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    restActive = false;
    restPaused = false;
    restRemaining = 0;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
