import 'package:flutter/material.dart';

import '../analytics_theme.dart';
import '../../../models/analytics_range.dart';

/// Global Week · Month · 3 Months segmented control (§4.1).
class RangeSelector extends StatelessWidget {
  final AnalyticsRange selected;
  final ValueChanged<AnalyticsRange> onChanged;

  const RangeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: AnalyticsRange.values.map((r) {
          final active = r == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(r),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? AnalyticsColors.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active
                          ? AnalyticsColors.ink
                          : AnalyticsColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
