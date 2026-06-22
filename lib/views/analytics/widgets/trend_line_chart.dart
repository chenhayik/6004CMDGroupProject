import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics_theme.dart';
import '../chart_scale.dart';
import '../../../models/trend_point.dart';

/// Reusable line chart (e.g. estimated 1RM). Requires ≥2 points to draw a
/// line; with a single point it shows just the dot (§10). PR dates passed in
/// [prDates] are drawn as enlarged markers.
class TrendLineChart extends StatelessWidget {
  final List<TrendPoint> points;
  final Color color;
  final String unit;
  final Set<DateTime> prDates;
  final double height;

  const TrendLineChart({
    super.key,
    required this.points,
    required this.color,
    this.unit = '',
    this.prDates = const {},
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final v = points[i].value;
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }

    final ys = spots.map((s) => s.y);
    final rawMax = ys.isEmpty ? 10.0 : ys.reduce((a, b) => a > b ? a : b);
    final rawMin = ys.isEmpty ? 0.0 : ys.reduce((a, b) => a < b ? a : b);
    // Clean rounded min/max/interval so the y labels don't overlap or read as
    // arbitrary values (worse on Month/3-Month where 1RM spreads are larger).
    final axis = niceRange(rawMin, rawMax);

    final labelEvery = points.length <= 8 ? 1 : (points.length / 6).ceil();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: axis.min,
          maxY: axis.max,
          lineTouchData: const LineTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: axis.interval,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AnalyticsColors.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: axis.interval,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min) return const SizedBox.shrink();
                  return Text(
                    v.toStringAsFixed(0),
                    style: const TextStyle(
                        fontSize: 9, color: AnalyticsColors.muted),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= points.length) {
                    return const SizedBox.shrink();
                  }
                  if (i % labelEvery != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      points[i].label,
                      style: const TextStyle(
                          fontSize: 9, color: AnalyticsColors.muted),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: color,
              barWidth: spots.length < 2 ? 0 : 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  final idx = spot.x.toInt();
                  final isPr = idx >= 0 &&
                      idx < points.length &&
                      prDates.contains(_dayOf(points[idx].date));
                  return FlDotCirclePainter(
                    radius: isPr ? 5 : 3,
                    color: isPr ? AnalyticsColors.carbs : color,
                    strokeWidth: isPr ? 2 : 0,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: spots.length >= 2,
                color: color.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
}
