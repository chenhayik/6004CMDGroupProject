import 'package:flutter/material.dart';
import '../../models/workout.dart';

const _green = Color(0xFF22C55E);
const _bg = Color(0xFFF8FAFC);
const _title = Color(0xFF0F172A);
const _amber = Color(0xFFF59E0B);

/// Post-workout summary: totals + any PRs hit.
class WorkoutSummaryView extends StatelessWidget {
  final Workout workout;
  const WorkoutSummaryView({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final prs = workout.exercises
        .expand((e) => e.sets.where((s) => s.isPR).map((s) => (e.name, s)))
        .toList();
    final mins = (workout.durationSec / 60).round();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        foregroundColor: _title,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                        color: Color(0xFFF0FDF4), shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle,
                        color: _green, size: 44),
                  ),
                  const SizedBox(height: 14),
                  const Text('Workout Complete',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _title)),
                  const SizedBox(height: 4),
                  Text(workout.name,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Totals ──
            Row(
              children: [
                _statCard('Duration', '$mins min', Icons.timer_outlined),
                const SizedBox(width: 10),
                _statCard('Volume',
                    '${workout.totalVolumeKg.toStringAsFixed(0)} kg',
                    Icons.fitness_center),
                const SizedBox(width: 10),
                _statCard('Sets', '${workout.completedSetCount}',
                    Icons.format_list_numbered),
              ],
            ),
            const SizedBox(height: 24),

            // ── PRs ──
            if (prs.isNotEmpty) ...[
              Row(
                children: const [
                  Icon(Icons.emoji_events, color: _amber, size: 20),
                  SizedBox(width: 6),
                  Text('Personal Records',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _title)),
                ],
              ),
              const SizedBox(height: 10),
              ...prs.map((p) => _prTile(p.$1, p.$2)),
              const SizedBox(height: 24),
            ],

            // ── Per-exercise recap ──
            const Text('Exercises',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _title)),
            const SizedBox(height: 10),
            ...workout.exercises.map(_exerciseRecap),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Done',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: _green, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _title)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ),
      ),
    );
  }

  Widget _prTile(String exerciseName, WorkoutSet s) {
    final detail = s.weightKg != null && s.reps != null
        ? '${s.weightKg!.toStringAsFixed(s.weightKg! == s.weightKg!.roundToDouble() ? 0 : 1)} kg × ${s.reps}'
        : s.reps != null
            ? '${s.reps} reps'
            : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: _amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(exerciseName,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: _title)),
          ),
          Text(detail,
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _exerciseRecap(WorkoutExercise ex) {
    final working = ex.sets.where((s) => s.countsForStats).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.fitness_center, color: _green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ex.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: _title)),
                const SizedBox(height: 2),
                Text(
                    '$working sets · ${ex.totalVolume().toStringAsFixed(0)} kg',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
