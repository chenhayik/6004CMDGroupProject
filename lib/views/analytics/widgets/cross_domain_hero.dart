import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics_theme.dart';
import '../../../models/trend_point.dart';

/// Cross-domain hero (§5.2): training volume × protein adherence.
///
/// Shown as GROUPED BARS on one honest 0–100% axis so the two are directly
/// comparable per day — a tall teal bar next to a short blue bar instantly
/// reads as "trained hard, under-ate protein". This replaces the old
/// dual-axis line+bar combo, which mixed kg and % on a single scale and drew a
/// misleading line connecting unlogged days.
///
/// - Training volume → % of the period's best day (teal).
/// - Protein adherence → % of daily target (blue).
/// - Unlogged buckets are gaps (no bar), never zero.
class CrossDomainHero extends StatelessWidget {
  final List<TrendPoint> volumeSeries; // value = volume per bucket (may gap)
  final List<TrendPoint> proteinSeries; // value vs target => adherence %
  final double height;

  const CrossDomainHero({
    super.key,
    required this.volumeSeries,
    required this.proteinSeries,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final n = proteinSeries.length;
    final vols = volumeSeries.where((p) => p.hasValue).map((p) => p.value!);
    final peakVol = vols.isEmpty ? 0.0 : vols.reduce((a, b) => a > b ? a : b);

    // Volume as % of the best day in the period.
    double? volPct(int i) {
      final v = i < volumeSeries.length ? volumeSeries[i].value : null;
      if (v == null || peakVol <= 0) return null;
      return (v / peakVol * 100).clamp(0, 100).toDouble();
    }

    // Protein as % of the daily target.
    double? protPct(int i) {
      final p = proteinSeries[i];
      if (!p.hasValue || p.target == null || p.target! <= 0) return null;
      return (p.value! / p.target! * 100).clamp(0, 100).toDouble();
    }

    final labelEvery = n <= 8 ? 1 : (n / 6).ceil();
    final barW = n > 16 ? 3.0 : 7.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: 100,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(enabled: false),
              groupsSpace: n > 12 ? 6 : 12,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 50,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: AnalyticsColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 50,
                    getTitlesWidget: (v, meta) {
                      if (![0, 50, 100].contains(v.round())) {
                        return const SizedBox.shrink();
                      }
                      return Text('${v.round()}%',
                          style: const TextStyle(
                              fontSize: 9, color: AnalyticsColors.muted));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= n || i % labelEvery != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(proteinSeries[i].label,
                            style: const TextStyle(
                                fontSize: 9, color: AnalyticsColors.muted)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < n; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      if (volPct(i) != null)
                        BarChartRodData(
                          toY: volPct(i)!,
                          width: barW,
                          color: AnalyticsColors.volume,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      if (protPct(i) != null)
                        BarChartRodData(
                          toY: protPct(i)!,
                          width: barW,
                          color: AnalyticsColors.protein,
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legend(AnalyticsColors.volume, 'Training volume'),
            const SizedBox(width: 16),
            _legend(AnalyticsColors.protein, 'Protein adherence'),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Each shown as a % — volume vs your best day, protein vs target.',
          style: TextStyle(fontSize: 10.5, color: AnalyticsColors.muted),
        ),
      ],
    );
  }

  Widget _legend(Color c, String label) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AnalyticsColors.muted)),
        ],
      );
}
