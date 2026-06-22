import 'package:intl/intl.dart';

/// Global time range for the whole Analytics screen.
///
/// Each range resolves to a window (how far back) and a bucket granularity
/// (how points are grouped). See §4.1 of the build spec.
enum AnalyticsRange { week, month, threeMonths }

/// How a range groups its points.
enum AnalyticsBucket { day, week }

/// One resolved bucket: a half-open date window [start, end) plus a short label.
class AnalyticsBucketWindow {
  final DateTime start; // inclusive, local midnight
  final DateTime end; // exclusive, local midnight
  final String label; // axis label, e.g. "Mon" or "16 Jun"

  const AnalyticsBucketWindow({
    required this.start,
    required this.end,
    required this.label,
  });

  /// Matches a `yyyy-MM-dd` day key against this bucket.
  bool containsDay(DateTime day) =>
      !day.isBefore(start) && day.isBefore(end);
}

extension AnalyticsRangeX on AnalyticsRange {
  String get label {
    switch (this) {
      case AnalyticsRange.week:
        return 'Week';
      case AnalyticsRange.month:
        return 'Month';
      case AnalyticsRange.threeMonths:
        return '3 Months';
    }
  }

  /// Number of calendar days in the window.
  int get windowDays {
    switch (this) {
      case AnalyticsRange.week:
        return 7;
      case AnalyticsRange.month:
        return 30;
      case AnalyticsRange.threeMonths:
        return 91; // ~13 weeks
    }
  }

  AnalyticsBucket get bucket {
    switch (this) {
      case AnalyticsRange.week:
      case AnalyticsRange.month:
        return AnalyticsBucket.day;
      case AnalyticsRange.threeMonths:
        return AnalyticsBucket.week;
    }
  }

  /// Local midnight of today.
  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Inclusive start of the window (local midnight).
  DateTime windowStart([DateTime? now]) {
    final today = now == null
        ? _today()
        : DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: windowDays - 1));
  }

  /// Exclusive end of the window (tomorrow's local midnight).
  DateTime windowEnd([DateTime? now]) {
    final today = now == null
        ? _today()
        : DateTime(now.year, now.month, now.day);
    return today.add(const Duration(days: 1));
  }

  /// Human-readable window subtitle, e.g. "16–22 Jun".
  String windowSubtitle([DateTime? now]) {
    final start = windowStart(now);
    final endInclusive = windowEnd(now).subtract(const Duration(days: 1));
    final dayFmt = DateFormat('d');
    final monthFmt = DateFormat('MMM');
    if (start.month == endInclusive.month) {
      return '${dayFmt.format(start)}–${dayFmt.format(endInclusive)} '
          '${monthFmt.format(endInclusive)}';
    }
    final shortFmt = DateFormat('d MMM');
    return '${shortFmt.format(start)} – ${shortFmt.format(endInclusive)}';
  }

  /// The previous equivalent window (same length, immediately before),
  /// used to compute period-over-period deltas.
  AnalyticsBucketWindow previousWindow([DateTime? now]) {
    final start = windowStart(now);
    final prevEnd = start; // exclusive
    final prevStart = start.subtract(Duration(days: windowDays));
    return AnalyticsBucketWindow(
      start: prevStart,
      end: prevEnd,
      label: 'prev',
    );
  }

  /// Builds the ordered list of buckets covering the window.
  List<AnalyticsBucketWindow> buckets([DateTime? now]) {
    final start = windowStart(now);
    final end = windowEnd(now);
    final result = <AnalyticsBucketWindow>[];

    if (bucket == AnalyticsBucket.day) {
      final dayFmt = this == AnalyticsRange.week
          ? DateFormat('EEE') // Mon, Tue
          : DateFormat('d'); // 1..30
      var cursor = start;
      while (cursor.isBefore(end)) {
        final next = cursor.add(const Duration(days: 1));
        result.add(AnalyticsBucketWindow(
          start: cursor,
          end: next,
          label: dayFmt.format(cursor),
        ));
        cursor = next;
      }
    } else {
      // Weekly buckets — align to 7-day blocks from the window start.
      final weekFmt = DateFormat('d MMM');
      var cursor = start;
      while (cursor.isBefore(end)) {
        var next = cursor.add(const Duration(days: 7));
        if (next.isAfter(end)) next = end;
        result.add(AnalyticsBucketWindow(
          start: cursor,
          end: next,
          label: weekFmt.format(cursor),
        ));
        cursor = next;
      }
    }
    return result;
  }
}
