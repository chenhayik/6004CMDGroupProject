import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../analytics_theme.dart';
import '../../../viewmodels/analytics_viewmodel.dart';
import '../widgets/analytic_card.dart';
import '../widgets/analytics_common.dart';
import '../widgets/activity_tiles.dart';
import '../widgets/cross_domain_hero.dart';
import '../widgets/trend_line_chart.dart';

const _weightColor = Color(0xFF6366F1);

class OverviewTab extends StatelessWidget {
  /// Jump to another segment (0=Overview, 1=Nutrition, 2=Workout).
  final ValueChanged<int> onJumpToTab;

  const OverviewTab({super.key, required this.onJumpToTab});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnalyticsViewModel>();
    final s = vm.summary;

    if (vm.isLoading && s == null) {
      return const _TabList(children: [
        SkeletonCard(height: 240),
        SizedBox(height: 12),
        SkeletonCard(height: 90),
      ]);
    }
    if (s == null) return const SizedBox.shrink();

    final bothEmpty = s.nutritionEmpty && s.workoutEmpty;
    if (bothEmpty) {
      return const _TabList(children: [
        EmptyCard(
          icon: Icons.insights_outlined,
          title: 'Not enough data yet',
          message: 'Log a few days of meals and workouts to unlock your trends.',
        ),
      ]);
    }

    final kcal = NumberFormat('#,###').format(s.avgCalories.current.round());

    return _TabList(children: [
      // 1. Cross-domain hero — training volume × protein adherence only.
      AnalyticCard(
        title: 'Volume × Protein',
        accent: AnalyticsColors.volume,
        chart: CrossDomainHero(
          volumeSeries: s.volumeSeries,
          proteinSeries: s.proteinSeries,
        ),
        takeaway: s.overviewTakeaway,
      ),
      const SizedBox(height: 12),

      // 2. Activity tiles — steps + water.
      ActivityTiles(
        steps: s.avgSteps,
        water: s.avgWater,
        hasData: s.hasActivity,
      ),
      const SizedBox(height: 12),

      // 2b. Body-weight trend (only once there's data to plot).
      if (s.hasWeight) ...[
        AnalyticCard(
          title: 'Weight',
          stat: s.weightLatestKg!.toStringAsFixed(1),
          statUnit: 'kg',
          accent: _weightColor,
          chart: TrendLineChart(
            points: s.weightSeries,
            color: _weightColor,
            unit: 'kg',
          ),
          takeaway: s.weightDeltaKg == null
              ? 'Log another weigh-in to see your trend.'
              : '${s.weightDeltaKg! >= 0 ? '+' : ''}'
                  '${s.weightDeltaKg!.toStringAsFixed(1)} kg over this period.',
        ),
        const SizedBox(height: 12),
      ],

      // 3. Summary cards — tappable, jump to the matching tab.
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Nutrition',
              value: kcal,
              unit: 'avg kcal',
              color: AnalyticsColors.calories,
              icon: Icons.local_fire_department_outlined,
              onTap: () => onJumpToTab(1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              label: 'Workouts',
              value: '${s.totalSessions}',
              unit: s.totalSessions == 1 ? 'session' : 'sessions',
              detail: '${s.prs.length} PR${s.prs.length == 1 ? '' : 's'}',
              color: AnalyticsColors.volume,
              icon: Icons.fitness_center,
              onTap: () => onJumpToTab(2),
            ),
          ),
        ],
      ),
    ]);
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String? detail;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.unit,
    this.detail,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AnalyticsColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AnalyticsColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AnalyticsColors.muted,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      size: 16, color: AnalyticsColors.muted),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AnalyticsColors.ink,
                ),
              ),
              Text(
                detail == null ? unit : '$unit · $detail',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AnalyticsColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrollable padded column shared by all tabs.
class _TabList extends StatelessWidget {
  final List<Widget> children;
  const _TabList({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: children,
    );
  }
}
