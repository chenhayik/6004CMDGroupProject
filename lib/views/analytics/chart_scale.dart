import 'dart:math';

/// Chart axis-scaling helpers shared by every time-series chart, so Week,
/// Month and 3-Month views all get clean, rounded gridlines instead of
/// arbitrary values derived from the raw data max.

/// A rounded gridline step (1, 2, 2.5 or 5 × 10ⁿ) for a value [range] split
/// into roughly [divisions] divisions.
double niceInterval(double range, {int divisions = 4}) {
  if (range <= 0 || range.isNaN || range.isInfinite) return 1;
  final rough = range / divisions;
  final mag = pow(10, (log(rough) / ln10).floor()).toDouble();
  final norm = rough / mag; // 1..10
  double step;
  if (norm <= 1) {
    step = 1;
  } else if (norm <= 2) {
    step = 2;
  } else if (norm <= 2.5) {
    step = 2.5;
  } else if (norm <= 5) {
    step = 5;
  } else {
    step = 10;
  }
  return step * mag;
}

/// A clean 0-based axis for bar charts: a rounded [max] strictly above
/// [rawMax] (so the tallest bar leaves headroom) plus the gridline [interval].
({double max, double interval}) niceAxis(double rawMax, {int divisions = 4}) {
  if (rawMax <= 0) return (max: 10, interval: 5);
  final interval = niceInterval(rawMax, divisions: divisions);
  // Round up to the next interval so the top bar never touches the ceiling.
  final max = ((rawMax / interval).floor() + 1) * interval;
  return (max: max, interval: interval);
}

/// A clean min/max/interval for a non-zero-based axis (e.g. estimated 1RM),
/// expanding [rawMin]/[rawMax] outward to rounded gridlines.
({double min, double max, double interval}) niceRange(
  double rawMin,
  double rawMax, {
  int divisions = 4,
}) {
  if (rawMax <= rawMin) {
    // Degenerate (one point / flat line): centre a small band on the value.
    final v = rawMax;
    final pad = v.abs() < 1 ? 5.0 : v * 0.1;
    return (min: (v - pad).clamp(0, double.infinity).toDouble(), max: v + pad, interval: niceInterval(pad * 2));
  }
  final interval = niceInterval(rawMax - rawMin, divisions: divisions);
  final min = ((rawMin / interval).floor()) * interval;
  final max = ((rawMax / interval).floor() + 1) * interval;
  return (min: min.clamp(0, double.infinity).toDouble(), max: max, interval: interval);
}
