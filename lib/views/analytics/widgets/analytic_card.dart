import 'package:flutter/material.dart';

import '../analytics_theme.dart';
import '../../../models/analytics_summary.dart';

/// Shared card shell (§7): title · headline stat · delta chip · chart · takeaway.
/// Material 3, rounded corners, optional press state for tappable cards.
class AnalyticCard extends StatelessWidget {
  final String title;
  final String? stat;
  final String? statUnit;
  final StatDelta? delta;
  final Widget? chart;
  final String? takeaway;
  final Color accent;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AnalyticCard({
    super.key,
    required this.title,
    this.stat,
    this.statUnit,
    this.delta,
    this.chart,
    this.takeaway,
    this.accent = AnalyticsColors.calories,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AnalyticsColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AnalyticsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w600,
                    color: AnalyticsColors.muted,
                  ),
                ),
              ),
              ?trailing,
              if (onTap != null && trailing == null)
                const Icon(Icons.chevron_right,
                    size: 18, color: AnalyticsColors.muted),
            ],
          ),
          if (stat != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  stat!,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AnalyticsColors.ink,
                  ),
                ),
                if (statUnit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    statUnit!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AnalyticsColors.muted,
                    ),
                  ),
                ],
                const Spacer(),
                if (delta != null && delta!.hasDelta) DeltaChip(delta: delta!),
              ],
            ),
          ],
          if (chart != null) ...[
            const SizedBox(height: 14),
            chart!,
          ],
          if (takeaway != null) ...[
            const SizedBox(height: 12),
            Text(
              takeaway!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AnalyticsColors.muted,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// ▲/▼ percentage chip vs the previous period.
class DeltaChip extends StatelessWidget {
  final StatDelta delta;

  /// When true (default) a positive delta is "good" (green). For metrics where
  /// lower is better, pass false to invert the colour.
  final bool higherIsBetter;

  const DeltaChip({super.key, required this.delta, this.higherIsBetter = true});

  @override
  Widget build(BuildContext context) {
    final up = delta.isPositive;
    final good = higherIsBetter ? up : !up;
    final color =
        good ? AnalyticsColors.positive : AnalyticsColors.negative;
    final pct = delta.delta!.abs();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
