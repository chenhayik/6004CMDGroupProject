import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics_theme.dart';

/// Average macro split donut (§5.3). Shares P/C/F colours with the dashboard.
class MacroDonut extends StatelessWidget {
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double height;

  const MacroDonut({
    super.key,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    final total = proteinG + carbsG + fatG;
    final segments = [
      (_Seg('Protein', proteinG, AnalyticsColors.protein)),
      (_Seg('Carbs', carbsG, AnalyticsColors.carbs)),
      (_Seg('Fat', fatG, AnalyticsColors.fat)),
    ];

    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 38,
                sectionsSpace: 2,
                startDegreeOffset: -90,
                sections: total <= 0
                    ? [
                        PieChartSectionData(
                          value: 1,
                          color: AnalyticsColors.border,
                          radius: 22,
                          showTitle: false,
                        )
                      ]
                    : segments
                        .map((s) => PieChartSectionData(
                              value: s.value,
                              color: s.color,
                              radius: 24,
                              title: '${(s.value / total * 100).round()}%',
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ))
                        .toList(),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: segments
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: s.color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s.label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AnalyticsColors.ink,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${s.value.round()}g',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AnalyticsColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg {
  final String label;
  final double value;
  final Color color;
  _Seg(this.label, this.value, this.color);
}
