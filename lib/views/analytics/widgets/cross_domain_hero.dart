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

  // Width of the right-hand % scale column (kept out of the plot area).
  static const double _scaleW = 30;

  @override
  Widget build(BuildContext context) {
    final n = proteinSeries.length;
    final vols = volumeSeries.where((p) => p.hasValue).map((p) => p.value!);
    final maxVol = vols.isEmpty ? 0.0 : vols.reduce((a, b) => a > b ? a : b);
    final volTop = maxVol <= 0 ? 1.0 : maxVol * 1.3;

    // Protein adherence % (0..100), normalised onto the same 0..volTop axis so
    // 100% sits at the top of the chart and 0% at the bottom.
    double? adherence(TrendPoint p) {
      if (!p.hasValue || p.target == null || p.target! <= 0) return null;
      return (p.value! / p.target! * 100).clamp(0, 100).toDouble();
    }

    final labelEvery = n <= 8 ? 1 : (n / 6).ceil();
    final hasProtein = proteinSeries.any((p) => adherence(p) != null);

    // Both charts are decoration-free and fill the SAME box, so their plot
    // rectangles coincide exactly — no axis reservations to knock them out of
    // alignment. Labels/scale are drawn outside the box.
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
        titlesData: const FlTitlesData(show: false),
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

    // Map % -> y = %/100 * volTop. minX/maxX are inset by half a slot so each
    // point sits under the centre of its spaceAround bar.
    final proteinSpots = <FlSpot>[];
    for (var i = 0; i < proteinSeries.length; i++) {
      final a = adherence(proteinSeries[i]);
      if (a != null) proteinSpots.add(FlSpot(i.toDouble(), a / 100 * volTop));
    }

    final lineChart = LineChart(
      LineChartData(
        maxY: volTop,
        minY: 0,
        minX: -0.5,
        maxX: n - 0.5,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: proteinSpots,
            isCurved: false,
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
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: barChart),
                    if (hasProtein) Positioned.fill(child: lineChart),
                  ],
                ),
              ),
              // Right-edge protein % scale (top=100%, bottom=0%).
              SizedBox(
                width: _scaleW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text('100%',
                          style: TextStyle(
                              fontSize: 9, color: AnalyticsColors.protein)),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text('50%',
                          style: TextStyle(
                              fontSize: 9, color: AnalyticsColors.protein)),
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text('0%',
                          style: TextStyle(
                              fontSize: 9, color: AnalyticsColors.protein)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Day labels, aligned under the bars (same width as the plot area).
        Padding(
          padding: const EdgeInsets.only(right: _scaleW),
          child: Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: Center(
                    child: i % labelEvery == 0
                        ? Text(proteinSeries[i].label,
                            style: const TextStyle(
                                fontSize: 9, color: AnalyticsColors.muted))
                        : const SizedBox.shrink(),
                  ),
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
