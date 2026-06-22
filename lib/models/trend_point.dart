/// One plottable datum on a trend series.
///
/// A `null` [value] marks an unlogged bucket — a GAP, not a zero (§10).
/// Widgets must skip null values rather than drawing them at the baseline.
class TrendPoint {
  final String label; // x-axis label for this bucket
  final DateTime date; // bucket start (local midnight)
  final double? value; // null => gap / not logged
  final double? target; // optional per-point goal line value

  const TrendPoint({
    required this.label,
    required this.date,
    required this.value,
    this.target,
  });

  bool get hasValue => value != null;
}

/// Stacked macro grams for one bucket (used by the macro-balance chart).
class MacroStackPoint {
  final String label;
  final DateTime date;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final bool logged;

  const MacroStackPoint({
    required this.label,
    required this.date,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.logged,
  });

  double get total => proteinG + carbsG + fatG;
}

/// A single calendar-day cell for the consistency heatmap.
class HeatCell {
  final DateTime date;
  final bool logged;
  final bool goalHit; // logged AND hit the relevant goal
  final double intensity; // 0..1 shading

  const HeatCell({
    required this.date,
    required this.logged,
    required this.goalHit,
    required this.intensity,
  });
}

/// A dated personal-record row for the workout PR feed.
class PrRecord {
  final String exerciseName;
  final DateTime date;
  final String metric; // e.g. "Best e1RM"
  final double value;
  final String unit; // "kg" / "lb"

  const PrRecord({
    required this.exerciseName,
    required this.date,
    required this.metric,
    required this.value,
    required this.unit,
  });
}
