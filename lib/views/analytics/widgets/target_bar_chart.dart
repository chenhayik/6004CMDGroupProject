import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics_theme.dart';
import '../../../models/trend_point.dart';

/// Reusable bar chart with an optional dashed target line (§5.3 / §6).
///
/// - Bars with a null value render as GAPS (no rod), never as a zero bar.
/// - When [target] and [overColor] are set, bars above target switch colour.
class TargetBarChart extends StatelessWidget {
  final List<TrendPoint> points;
  final double? target;
  final Color barColor;
  final Color? overColor;
  final double height;

  const TargetBarChart({
    super.key,
    required this.points,
    required this.barColor,
    this.target,
    this.overColor,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final values = points.where((p) => p.hasValue).map((p) => p.value!).toList();
    final maxData = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = [
      maxData,
      ?target,
    ].fold<double>(0, (a, b) => a > b ? a : b);
    final top = maxY <= 0 ? 10.0 : maxY * 1.25;

    // For dense day buckets, only label a handful of bars.
    final labelEvery = points.length <= 8
        ? 1
        : points.length <= 16
            ? 3
            : 5;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: top,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 3,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AnalyticsColors.border,
              strokeWidth: 1,
            ),
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
                interval: top / 3,
                getTitlesWidget: (v, meta) {
                  if (v == 0) return const SizedBox.shrink();
                  return Text(
                    _compact(v),
                    style: const TextStyle(
                      fontSize: 9,
                      color: AnalyticsColors.muted,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
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
                        fontSize: 9,
                        color: AnalyticsColors.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: target == null
              ? const ExtraLinesData()
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: target!,
                    color: AnalyticsColors.targetLine,
                    strokeWidth: 1.5,
                    dashArray: const [6, 4],
                  ),
                ]),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  if (points[i].hasValue)
                    BarChartRodData(
                      toY: points[i].value!,
                      width: points.length > 16 ? 5 : 12,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3)),
                      color: _colorFor(points[i].value!),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(double v) {
    if (target != null && overColor != null && v > target!) return overColor!;
    return barColor;
  }

  static String _compact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }
}
