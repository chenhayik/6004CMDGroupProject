import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics_theme.dart';
import '../../../models/trend_point.dart';

/// Macro balance over time — P/C/F grams stacked per bucket via
/// `rodStackItems` (§5.3 / §6). Unlogged buckets render as gaps.
class MacroStackedBarChart extends StatelessWidget {
  final List<MacroStackPoint> points;
  final double height;

  const MacroStackedBarChart({
    super.key,
    required this.points,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final totals = points.where((p) => p.logged).map((p) => p.total);
    final maxTotal = totals.isEmpty ? 0.0 : totals.reduce((a, b) => a > b ? a : b);
    final top = maxTotal <= 0 ? 10.0 : maxTotal * 1.2;
    final labelEvery = points.length <= 8 ? 1 : (points.length / 6).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
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
                    getTitlesWidget: (v, meta) {
                      if (v == 0) return const SizedBox.shrink();
                      return Text('${v.toInt()}g',
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
                      if (i < 0 || i >= points.length || i % labelEvery != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(points[i].label,
                            style: const TextStyle(
                                fontSize: 9, color: AnalyticsColors.muted)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < points.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    if (points[i].logged && points[i].total > 0)
                      BarChartRodData(
                        toY: points[i].total,
                        width: points.length > 16 ? 5 : 12,
                        borderRadius: BorderRadius.circular(2),
                        rodStackItems: _stack(points[i]),
                      ),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legend(AnalyticsColors.protein, 'Protein'),
            const SizedBox(width: 14),
            _legend(AnalyticsColors.carbs, 'Carbs'),
            const SizedBox(width: 14),
            _legend(AnalyticsColors.fat, 'Fat'),
          ],
        ),
      ],
    );
  }

  List<BarChartRodStackItem> _stack(MacroStackPoint p) {
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    void add(double g, Color c) {
      if (g <= 0) return;
      items.add(BarChartRodStackItem(from, from + g, c));
      from += g;
    }

    add(p.proteinG, AnalyticsColors.protein);
    add(p.carbsG, AnalyticsColors.carbs);
    add(p.fatG, AnalyticsColors.fat);
    return items;
  }

  Widget _legend(Color c, String label) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 5),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AnalyticsColors.muted)),
        ],
      );
}
