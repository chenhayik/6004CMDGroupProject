import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics_theme.dart';

/// Muscle-group balance radar (§5.4). Volume per muscle group.
class MuscleRadar extends StatelessWidget {
  final Map<String, double> muscleVolume;
  final double height;

  const MuscleRadar({
    super.key,
    required this.muscleVolume,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    // Radar needs at least 3 axes to render a sensible shape.
    final entries = muscleVolume.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.length < 3) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            entries.isEmpty
                ? 'No muscle-group data yet.'
                : 'Train more muscle groups to see your balance.',
            style: const TextStyle(
                fontSize: 12, color: AnalyticsColors.muted),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          radarBackgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          gridBorderData: const BorderSide(
              color: AnalyticsColors.border, width: 1),
          tickBorderData: const BorderSide(
              color: AnalyticsColors.border, width: 0.5),
          ticksTextStyle:
              const TextStyle(color: Colors.transparent, fontSize: 1),
          tickCount: 4,
          titlePositionPercentageOffset: 0.12,
          getTitle: (index, angle) {
            if (index >= entries.length) return const RadarChartTitle(text: '');
            return RadarChartTitle(text: entries[index].key);
          },
          titleTextStyle: const TextStyle(
            fontSize: 10,
            color: AnalyticsColors.muted,
            fontWeight: FontWeight.w500,
          ),
          dataSets: [
            RadarDataSet(
              fillColor: AnalyticsColors.volume.withValues(alpha: 0.22),
              borderColor: AnalyticsColors.volume,
              borderWidth: 2,
              entryRadius: 2,
              dataEntries: entries
                  .map((e) => RadarEntry(value: e.value))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
