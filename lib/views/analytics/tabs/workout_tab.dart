import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../analytics_theme.dart';
import '../../../models/trend_point.dart';
import '../../../viewmodels/analytics_viewmodel.dart';
import '../widgets/analytic_card.dart';
import '../widgets/analytics_common.dart';
import '../widgets/target_bar_chart.dart';
import '../widgets/trend_line_chart.dart';
import '../widgets/muscle_radar.dart';
import '../widgets/consistency_heatmap.dart';

class WorkoutTab extends StatelessWidget {
  const WorkoutTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnalyticsViewModel>();
    final s = vm.summary;

    if (vm.isLoading && s == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: const [
          SkeletonCard(height: 90),
          SizedBox(height: 12),
          SkeletonCard(height: 230),
        ],
      );
    }
    if (s == null) return const SizedBox.shrink();

    if (s.workoutEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: const [
          EmptyCard(
            icon: Icons.fitness_center,
            title: 'No workouts logged yet',
            message:
                'Log a few training sessions to see your volume, estimated 1RM, PRs and muscle balance here.',
          ),
        ],
      );
    }

    final selectedId = vm.selectedExerciseId;
    final e1rmSeries = selectedId == null
        ? const <TrendPoint>[]
        : (s.e1rmByExercise[selectedId] ?? const <TrendPoint>[]);
    final prDates = s.prs.map((p) => _day(p.date)).toSet();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        StatRow(items: [
          StatItem('Volume', _compact(s.totalVolume.current),
              color: AnalyticsColors.volume),
          StatItem('Sessions', '${s.totalSessions}'),
          StatItem('Sets', '${s.totalSets}'),
          StatItem('Streak', '${s.workoutStreak}d'),
        ]),
        const SizedBox(height: 12),

        // Training volume per bucket (no target line)
        AnalyticCard(
          title: 'Training volume',
          stat: _compact(s.totalVolume.current),
          statUnit: 'kg total',
          accent: AnalyticsColors.volume,
          chart: TargetBarChart(
            points: s.volumeSeries,
            barColor: AnalyticsColors.volume,
          ),
          takeaway: s.workoutTakeaway,
        ),
        const SizedBox(height: 12),

        // Est. 1RM per lift with exercise dropdown
        if (s.e1rmByExercise.isNotEmpty)
          AnalyticCard(
            title: 'Estimated 1RM',
            accent: AnalyticsColors.protein,
            trailing: _ExerciseDropdown(
              ids: s.e1rmByExercise.keys.toList(),
              names: s.exerciseNames,
              selected: selectedId,
              onChanged: (id) => context
                  .read<AnalyticsViewModel>()
                  .selectExercise(id),
            ),
            chart: e1rmSeries.length < 2
                ? _SinglePointNote(series: e1rmSeries)
                : TrendLineChart(
                    points: e1rmSeries,
                    color: AnalyticsColors.protein,
                    prDates: prDates,
                  ),
          ),
        if (s.e1rmByExercise.isNotEmpty) const SizedBox(height: 12),

        // Personal records feed
        if (s.prs.isNotEmpty) ...[
          AnalyticCard(
            title: 'Personal records',
            accent: AnalyticsColors.carbs,
            chart: Column(
              children: s.prs
                  .take(6)
                  .map((pr) => _PrRow(
                        name: pr.exerciseName,
                        value: '${pr.value.toStringAsFixed(1)} ${pr.unit}',
                        date: DateFormat('d MMM').format(pr.date),
                        metric: pr.metric,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Frequency heatmap
        AnalyticCard(
          title: 'Frequency',
          accent: AnalyticsColors.volume,
          chart: ConsistencyHeatmap(
            cells: s.workoutHeat,
            baseColor: AnalyticsColors.volume,
          ),
          takeaway: '${s.totalSessions} sessions in this period.',
        ),
        const SizedBox(height: 12),

        // Muscle balance radar
        AnalyticCard(
          title: 'Muscle-group balance',
          accent: AnalyticsColors.volume,
          chart: MuscleRadar(muscleVolume: s.muscleVolume),
        ),
      ],
    );
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _compact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _ExerciseDropdown extends StatelessWidget {
  final List<String> ids;
  final Map<String, String> names;
  final String? selected;
  final ValueChanged<String> onChanged;

  const _ExerciseDropdown({
    required this.ids,
    required this.names,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selected,
        isDense: true,
        borderRadius: BorderRadius.circular(12),
        style: const TextStyle(
            fontSize: 12.5,
            color: AnalyticsColors.ink,
            fontWeight: FontWeight.w600),
        icon: const Icon(Icons.expand_more, size: 18),
        items: ids
            .map((id) => DropdownMenuItem(
                  value: id,
                  child: Text(names[id] ?? id),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _SinglePointNote extends StatelessWidget {
  final List<TrendPoint> series;
  const _SinglePointNote({required this.series});

  @override
  Widget build(BuildContext context) {
    final v = series.isEmpty ? null : series.first.value;
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          v == null
              ? 'No 1RM data in this range.'
              : 'One data point (${v.toStringAsFixed(1)}). Log again to draw a trend.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AnalyticsColors.muted),
        ),
      ),
    );
  }
}

class _PrRow extends StatelessWidget {
  final String name;
  final String value;
  final String date;
  final String metric;

  const _PrRow({
    required this.name,
    required this.value,
    required this.date,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined,
              size: 18, color: AnalyticsColors.carbs),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AnalyticsColors.ink)),
                Text(metric,
                    style: const TextStyle(
                        fontSize: 11, color: AnalyticsColors.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AnalyticsColors.volume)),
              Text(date,
                  style: const TextStyle(
                      fontSize: 11, color: AnalyticsColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
