import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics_theme.dart';
import '../../../models/trend_point.dart';

/// Cross-domain hero (§5.2): training VOLUME (bars) × PROTEIN adherence (line),
/// normalised to 0–100% on the right edge. fl_chart has no native combo, so a
/// BarChart and a LineChart are stacked sharing identical X/Y bounds (§6).
///
/// Only training volume × protein — no steps/water here (per spec).
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
    final maxVol = vols.isEmpty ? 0.0 : vols.reduce((a, b) => a > b ? a : b);
    final volTop = maxVol <= 0 ? 1.0 : maxVol * 1.3;

    // Protein adherence % (0..100+), capped at 100 for the line per spec.
    double? adherence(TrendPoint p) {
      if (!p.hasValue || p.target == null || p.target! <= 0) return null;
      return (p.value! / p.target! * 100).clamp(0, 100).toDouble();
    }

    final labelEvery = n <= 8 ? 1 : (n / 6).ceil();

    final barChart = BarChart(
      BarChartData(
        maxY: volTop,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AnalyticsColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 50,
              getTitlesWidget: (v, meta) {
                // Right axis is the protein % scale (0,50,100).
                final pct = (v / volTop * 100).round();
                if (![0, 50, 100].contains(pct)) {
                  return const SizedBox.shrink();
                }
                return Text('$pct%',
                    style: const TextStyle(
                        fontSize: 9, color: AnalyticsColors.protein));
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
          for (var i = 0; i < volumeSeries.length; i++)
            BarChartGroupData(x: i, barRods: [
              if (volumeSeries[i].hasValue)
                BarChartRodData(
                  toY: volumeSeries[i].value!,
                  width: n > 16 ? 5 : 11,
                  color: AnalyticsColors.volume.withValues(alpha: 0.85),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(3)),
                ),
            ]),
        ],
      ),
    );

    // Protein line on the SAME 0..volTop scale: map % -> y = %/100 * volTop.
    final proteinSpots = <FlSpot>[];
    for (var i = 0; i < proteinSeries.length; i++) {
      final a = adherence(proteinSeries[i]);
      if (a != null) proteinSpots.add(FlSpot(i.toDouble(), a / 100 * volTop));
    }

    final lineChart = LineChart(
      LineChartData(
        maxY: volTop,
        minY: 0,
        minX: 0,
        maxX: (n - 1).toDouble(),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: proteinSpots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: AnalyticsColors.protein,
            barWidth: proteinSpots.length < 2 ? 0 : 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: AnalyticsColors.protein,
                strokeWidth: 0,
                strokeColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: barChart),
              // Inset the line so it aligns with bars inside the right axis.
              Positioned.fill(
                right: 28,
                child: lineChart,
              ),
            ],
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
