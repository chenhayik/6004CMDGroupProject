import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../analytics_theme.dart';
import '../../../viewmodels/analytics_viewmodel.dart';
import '../widgets/analytic_card.dart';
import '../widgets/analytics_common.dart';
import '../widgets/target_bar_chart.dart';
import '../widgets/macro_donut.dart';
import '../widgets/macro_stacked_bar_chart.dart';
import '../widgets/consistency_heatmap.dart';

class NutritionTab extends StatelessWidget {
  const NutritionTab({super.key});

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
          SizedBox(height: 12),
          SkeletonCard(height: 230),
        ],
      );
    }
    if (s == null) return const SizedBox.shrink();

    if (s.nutritionEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          if (s.daysLogged == 1)
            const _PartialNote(text: '1 day logged so far — keep going.'),
          const EmptyCard(
            icon: Icons.restaurant_outlined,
            title: 'Log a few days to unlock your trends',
            message:
                'Your calorie, protein and macro trends appear once you have at least two logged days.',
          ),
        ],
      );
    }

    final kcal = NumberFormat('#,###').format(s.avgCalories.current.round());

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        if (s.daysLogged < s.totalDays)
          _PartialNote(
              text: '${s.daysLogged} of ${s.totalDays} days logged.'),

        // Stat row
        StatRow(items: [
          StatItem('Avg kcal', kcal, color: AnalyticsColors.calories),
          StatItem('Avg protein', '${s.avgProtein.current.round()}g',
              color: AnalyticsColors.protein),
          StatItem('On target', '${s.daysOnTarget}d'),
          StatItem('Streak', '${s.loggingStreak}d'),
        ]),
        const SizedBox(height: 12),

        // Calories vs target
        AnalyticCard(
          title: 'Calories vs target',
          stat: kcal,
          statUnit: 'avg kcal',
          delta: s.avgCalories,
          accent: AnalyticsColors.calories,
          chart: TargetBarChart(
            points: s.caloriesSeries,
            barColor: AnalyticsColors.calories,
            overColor: AnalyticsColors.carbs, // amber when over target
            target: s.targetKcal > 0 ? s.targetKcal.toDouble() : null,
          ),
          takeaway: s.nutritionTakeaway,
        ),
        const SizedBox(height: 12),

        // Protein vs target
        AnalyticCard(
          title: 'Protein vs target',
          stat: '${s.avgProtein.current.round()}',
          statUnit: 'avg g',
          delta: s.avgProtein,
          accent: AnalyticsColors.protein,
          chart: TargetBarChart(
            points: s.proteinSeries,
            barColor: AnalyticsColors.protein,
            target: s.targetProteinG > 0 ? s.targetProteinG.toDouble() : null,
          ),
        ),
        const SizedBox(height: 12),

        // Macro split donut
        AnalyticCard(
          title: 'Macro split (avg)',
          accent: AnalyticsColors.protein,
          chart: MacroDonut(
            proteinG: s.macroAvgProteinG,
            carbsG: s.macroAvgCarbsG,
            fatG: s.macroAvgFatG,
          ),
        ),
        const SizedBox(height: 12),

        // Macro balance over time
        AnalyticCard(
          title: 'Macro balance over time',
          accent: AnalyticsColors.carbs,
          chart: MacroStackedBarChart(points: s.macroStackSeries),
        ),
        const SizedBox(height: 12),

        // Consistency heatmap
        AnalyticCard(
          title: 'Consistency',
          accent: AnalyticsColors.calories,
          chart: ConsistencyHeatmap(
            cells: s.nutritionHeat,
            baseColor: AnalyticsColors.calories,
          ),
          takeaway:
              '${s.daysLogged} logged days · ${s.daysOnTarget} on calorie target.',
        ),
      ],
    );
  }
}

class _PartialNote extends StatelessWidget {
  final String text;
  const _PartialNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AnalyticsColors.muted),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AnalyticsColors.muted)),
        ],
      ),
    );
  }
}
