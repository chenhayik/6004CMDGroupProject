import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/routine.dart';
import '../../models/user_profile.dart';
import '../../models/workout.dart';
import '../../services/firestore_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/workout_service.dart';
import '../../viewmodels/active_workout_viewmodel.dart';
import 'active_workout_view.dart';

const _green = Color(0xFF22C55E);
const _bg = Color(0xFFF8FAFC);
const _title = Color(0xFF0F172A);

class WorkoutHomeView extends StatefulWidget {
  const WorkoutHomeView({super.key});

  @override
  State<WorkoutHomeView> createState() => _WorkoutHomeViewState();
}

class _WorkoutHomeViewState extends State<WorkoutHomeView> {
  final ActiveWorkoutViewModel _vm = ActiveWorkoutViewModel();
  final RecommendationService _recommender = RecommendationService();

  List<Workout> _history = [];
  bool _loading = true;

  UserProfile? _profile;
  int _daysPerWeek = 3;
  Routine? _recommended;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _vm.init();
    await _loadProfile();
    await _loadHistory();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await FirestoreService().getUserProfile(uid);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      if (profile != null) {
        _daysPerWeek = _recommender.defaultDaysPerWeek(
          activityLevel: profile.activityLevel,
          goal: profile.goal,
        );
      }
    });
  }

  Future<void> _loadHistory() async {
    final h = await WorkoutService().getHistory(limit: 30);
    if (!mounted) return;
    setState(() {
      _history = h;
      _loading = false;
      _rebuildRecommendation();
    });
  }

  void _rebuildRecommendation() {
    if (_profile == null) return;
    _recommended = _recommender.recommend(
      goal: _profile!.goal,
      activityLevel: _profile!.activityLevel,
      daysPerWeek: _daysPerWeek,
      history: _history,
    );
  }

  void _setDays(int days) {
    setState(() {
      _daysPerWeek = days;
      _rebuildRecommendation();
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _openActive({bool startNew = false, Routine? routine}) async {
    if (routine != null) {
      _vm.startFromRoutine(routine);
    } else if (startNew) {
      _vm.startEmpty();
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: _vm,
          child: const ActiveWorkoutView(),
        ),
      ),
    );
    // Returned from the session — refresh history (a workout may be saved).
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _title,
        title: const Text(
          'Gym',
          style: TextStyle(fontWeight: FontWeight.bold, color: _title),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Resume banner (in-progress session restored) ──
            AnimatedBuilder(
              animation: _vm,
              builder: (_, _) {
                if (!_vm.hasActiveSession) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ResumeBanner(
                    vm: _vm,
                    onResume: () => _openActive(startNew: false),
                    onDiscard: () => _vm.discard(),
                  ),
                );
              },
            ),

            // ── Goal-based recommendation ──
            if (_recommended != null) ...[
              _RecommendationCard(
                routine: _recommended!,
                goal: _profile?.goal ?? '',
                daysPerWeek: _daysPerWeek,
                onDaysChanged: _setDays,
                onStart: () => _openActive(routine: _recommended),
              ),
              const SizedBox(height: 14),
            ],

            // ── Start workout CTA ──
            _StartCard(onTap: () => _openActive(startNew: true)),
            const SizedBox(height: 24),

            const Text(
              'History',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: _title),
            ),
            const SizedBox(height: 12),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_history.isEmpty)
              _emptyHistory()
            else
              ..._history.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryCard(workout: w),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _emptyHistory() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.fitness_center,
                size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No workouts yet',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54)),
            const SizedBox(height: 4),
            const Text('Start a workout to begin tracking',
                style: TextStyle(fontSize: 12, color: Colors.black38)),
          ],
        ),
      );
}

class _StartCard extends StatelessWidget {
  final VoidCallback onTap;
  const _StartCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_green, Color(0xFF15803D)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: _green.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Start Empty Workout',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  SizedBox(height: 2),
                  Text('Log lifts, cardio and more',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  final ActiveWorkoutViewModel vm;
  final VoidCallback onResume;
  final VoidCallback onDiscard;
  const _ResumeBanner(
      {required this.vm, required this.onResume, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    final w = vm.workout!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill, color: _green, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Workout in progress',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: _title)),
                Text(
                  '${w.exercises.length} exercises · resume to continue',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onDiscard,
            style: TextButton.styleFrom(foregroundColor: Colors.black45),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: onResume,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Resume',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Routine routine;
  final String goal;
  final int daysPerWeek;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback onStart;

  const _RecommendationCard({
    required this.routine,
    required this.goal,
    required this.daysPerWeek,
    required this.onDaysChanged,
    required this.onStart,
  });

  String get _goalLabel {
    switch (goal.toLowerCase()) {
      case 'cut':
        return 'fat loss';
      case 'bulk':
        return 'muscle gain';
      default:
        return 'maintenance';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: _green, size: 18),
              const SizedBox(width: 6),
              Text(
                'Recommended for $_goalLabel',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _green,
                    letterSpacing: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(routine.name,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _title)),
          if (routine.focusSummary != null) ...[
            const SizedBox(height: 2),
            Text(routine.focusSummary!,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],
          const SizedBox(height: 12),

          // ── Days/week selector ──
          Row(
            children: [
              const Text('Days/week',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(width: 10),
              ...[3, 4, 5].map((d) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => onDaysChanged(d),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: daysPerWeek == d ? _green : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: daysPerWeek == d
                                  ? _green
                                  : Colors.grey.shade300),
                        ),
                        child: Text('$d',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: daysPerWeek == d
                                    ? Colors.white
                                    : Colors.black54)),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 12),

          // ── Exercise preview ──
          ...routine.exercises.take(6).map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 5, color: Colors.black38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.name,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87)),
                    ),
                    Text(e.targetLabel,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                  ],
                ),
              )),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
              ),
              child: const Text('Start This Workout',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Workout workout;
  const _HistoryCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final date = workout.finishedAt ?? workout.startedAt;
    final dateLabel = DateFormat('EEE, MMM d · h:mm a').format(date);
    final mins = (workout.durationSec / 60).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(workout.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(dateLabel,
                  style: const TextStyle(fontSize: 11, color: Colors.black38)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stat(Icons.timer_outlined, '$mins min'),
              const SizedBox(width: 16),
              _stat(Icons.format_list_numbered, '${workout.completedSetCount} sets'),
              const SizedBox(width: 16),
              _stat(Icons.fitness_center,
                  '${workout.totalVolumeKg.toStringAsFixed(0)} kg'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            workout.exercises.map((e) => e.name).join(' · '),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 14, color: Colors.black38),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      );
}
