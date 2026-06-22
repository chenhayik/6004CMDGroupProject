import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics_theme.dart';
import '../../../models/trend_point.dart';

/// Calendar consistency heatmap built from a cheap, fully-styleable
/// `GridView`-style layout (the spec permits a custom grid in place of the
/// heatmap package). One cell per day, shaded by logged / goal-hit (§5.3/§5.4).
class ConsistencyHeatmap extends StatelessWidget {
  final List<HeatCell> cells;
  final Color baseColor;

  const ConsistencyHeatmap({
    super.key,
    required this.cells,
    this.baseColor = AnalyticsColors.calories,
  });

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) return const SizedBox.shrink();

    // Pad the front so the first column starts on the right weekday (Mon=0).
    final firstWeekday = (cells.first.date.weekday + 6) % 7; // Mon-based
    final padded = <HeatCell?>[
      ...List<HeatCell?>.filled(firstWeekday, null),
      ...cells,
    ];

    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: labels
              .map((l) => Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AnalyticsColors.muted,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: padded.map(_cell).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Text('Less',
                style:
                    TextStyle(fontSize: 9, color: AnalyticsColors.muted)),
            const SizedBox(width: 6),
            _legendBox(const Color(0xFFEDF2F7)),
            _legendBox(baseColor.withValues(alpha: 0.45)),
            _legendBox(baseColor),
            const SizedBox(width: 6),
            const Text('More',
                style:
                    TextStyle(fontSize: 9, color: AnalyticsColors.muted)),
          ],
        ),
      ],
    );
  }

  Widget _cell(HeatCell? c) {
    Color color;
    if (c == null) {
      color = Colors.transparent;
    } else if (!c.logged) {
      color = const Color(0xFFEDF2F7); // gap
    } else if (c.goalHit) {
      color = baseColor;
    } else {
      color = baseColor.withValues(alpha: 0.45);
    }
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _legendBox(Color c) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      );

  static String monthLabel(DateTime d) => DateFormat('MMM').format(d);
}
