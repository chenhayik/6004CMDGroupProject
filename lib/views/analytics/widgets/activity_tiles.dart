import 'package:flutter/material.dart';

import '../analytics_theme.dart';
import 'analytic_card.dart';
import '../../../models/analytics_summary.dart';

/// Two compact tiles — Steps avg and Water avg — with delta arrows (§5.2).
class ActivityTiles extends StatelessWidget {
  final StatDelta steps;
  final StatDelta water;
  final bool hasData;

  const ActivityTiles({
    super.key,
    required this.steps,
    required this.water,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasData) {
      return _Tile(
        icon: Icons.timeline,
        color: AnalyticsColors.muted,
        value: '—',
        label: 'Steps & water build up as you log each day',
        delta: null,
        wide: true,
      );
    }
    return Row(
      children: [
        Expanded(
          child: _Tile(
            icon: Icons.directions_walk,
            color: AnalyticsColors.calories,
            value: _compact(steps.current),
            label: 'STEPS / DAY',
            delta: steps,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Tile(
            icon: Icons.water_drop_outlined,
            color: AnalyticsColors.water,
            value: '${water.current.toStringAsFixed(1)}L',
            label: 'WATER / DAY',
            delta: water,
          ),
        ),
      ],
    );
  }

  static String _compact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final StatDelta? delta;
  final bool wide;

  const _Tile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.delta,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AnalyticsColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AnalyticsColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AnalyticsColors.ink,
                      ),
                    ),
                    if (delta != null && delta!.hasDelta) ...[
                      const SizedBox(width: 8),
                      DeltaChip(delta: delta!),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.4,
                    color: AnalyticsColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
