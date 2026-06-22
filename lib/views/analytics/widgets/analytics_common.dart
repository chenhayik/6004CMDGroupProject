import 'package:flutter/material.dart';

import '../analytics_theme.dart';

/// A compact stat (label + value) used in the nutrition/workout stat rows.
class StatItem {
  final String label;
  final String value;
  final Color? color;
  const StatItem(this.label, this.value, {this.color});
}

/// Horizontal row of small stats inside a card (§5.3 / §5.4).
class StatRow extends StatelessWidget {
  final List<StatItem> items;
  const StatRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AnalyticsColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AnalyticsColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Text(
                    items[i].value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: items[i].color ?? AnalyticsColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.3,
                      color: AnalyticsColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              Container(
                width: 1,
                height: 30,
                color: AnalyticsColors.border,
              ),
          ],
        ],
      ),
    );
  }
}

/// Friendly empty-state card (§9). Never draws empty axes.
class EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AnalyticsColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AnalyticsColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: AnalyticsColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AnalyticsColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AnalyticsColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer-free skeleton card shaped like a chart (§9 loading).
class SkeletonCard extends StatefulWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 200});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = 0.4 + _c.value * 0.4;
        final shade = Color.lerp(
            const Color(0xFFEDF2F7), const Color(0xFFE2E8F0), v)!;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AnalyticsColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AnalyticsColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(shade, width: 90, height: 12),
              const SizedBox(height: 12),
              _bar(shade, width: 140, height: 24),
              const SizedBox(height: 16),
              Container(
                height: widget.height - 90,
                decoration: BoxDecoration(
                  color: shade,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(Color c, {required double width, required double height}) =>
      Container(
        width: width,
        height: height,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
      );
}

/// Slim "showing saved data" banner for offline mode (§9).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 14, color: Color(0xFF92400E)),
          SizedBox(width: 8),
          Text(
            'Showing saved data',
            style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
          ),
        ],
      ),
    );
  }
}
