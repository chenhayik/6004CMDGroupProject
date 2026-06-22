import 'package:intl/intl.dart';

/// Global time range for the whole Analytics screen.
///
/// Ranges are CALENDAR-ALIGNED (not rolling windows):
///   • Week  → the current week, Monday–Sunday, bucketed per day.
///   • Month → the current calendar month from the 1st, bucketed per day.
///   • 3 Months → the current calendar quarter (Jan–Mar, Apr–Jun, Jul–Sep,
///                Oct–Dec), bucketed per month (3 bars).
enum AnalyticsRange { week, month, threeMonths }

/// How a range groups its points.
enum AnalyticsBucket { day, month }

/// One resolved bucket: a half-open date window [start, end) plus a short label.
class AnalyticsBucketWindow {
  final DateTime start; // inclusive, local midnight
  final DateTime end; // exclusive, local midnight
  final String label; // axis label, e.g. "Mon", "16" or "Apr"

  const AnalyticsBucketWindow({
    required this.start,
    required this.end,
    required this.label,
  });

  /// Matches a day against this bucket.
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

  AnalyticsBucket get bucket {
    switch (this) {
      case AnalyticsRange.week:
      case AnalyticsRange.month:
        return AnalyticsBucket.day;
      case AnalyticsRange.threeMonths:
        return AnalyticsBucket.month;
    }
  }

  static DateTime _dateOnly(DateTime? now) {
    final d = now ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  /// First month (1..10) of the calendar quarter containing [month].
  static int _quarterFirstMonth(int month) => ((month - 1) ~/ 3) * 3 + 1;

  /// Inclusive start of the period (local midnight).
  DateTime windowStart([DateTime? now]) {
    final today = _dateOnly(now);
    switch (this) {
      case AnalyticsRange.week:
        // Monday of the current week (DateTime.weekday: Mon=1 … Sun=7).
        return today.subtract(Duration(days: today.weekday - 1));
      case AnalyticsRange.month:
        return DateTime(today.year, today.month, 1);
      case AnalyticsRange.threeMonths:
        return DateTime(today.year, _quarterFirstMonth(today.month), 1);
    }
  }

  /// Exclusive end of the period (local midnight).
  DateTime windowEnd([DateTime? now]) {
    final today = _dateOnly(now);
    switch (this) {
      case AnalyticsRange.week:
        return windowStart(now).add(const Duration(days: 7));
      case AnalyticsRange.month:
        return DateTime(today.year, today.month + 1, 1);
      case AnalyticsRange.threeMonths:
        return DateTime(today.year, _quarterFirstMonth(today.month) + 3, 1);
    }
  }

  /// Human-readable subtitle for the resolved period.
  String windowSubtitle([DateTime? now]) {
    switch (this) {
      case AnalyticsRange.week:
        final start = windowStart(now);
        final endInclusive = windowEnd(now).subtract(const Duration(days: 1));
        final d = DateFormat('d');
        final mon = DateFormat('MMM');
        if (start.month == endInclusive.month) {
          return '${d.format(start)}–${d.format(endInclusive)} '
              '${mon.format(endInclusive)}';
        }
        final dm = DateFormat('d MMM');
        return '${dm.format(start)} – ${dm.format(endInclusive)}';
      case AnalyticsRange.month:
        return DateFormat('MMMM yyyy').format(windowStart(now));
      case AnalyticsRange.threeMonths:
        final start = windowStart(now);
        final lastMonth = windowEnd(now).subtract(const Duration(days: 1));
        final mon = DateFormat('MMM');
        return '${mon.format(start)}–${mon.format(lastMonth)} ${start.year}';
    }
  }

  /// The previous equivalent calendar period (used for deltas).
  AnalyticsBucketWindow previousWindow([DateTime? now]) {
    final start = windowStart(now);
    switch (this) {
      case AnalyticsRange.week:
        return AnalyticsBucketWindow(
          start: start.subtract(const Duration(days: 7)),
          end: start,
          label: 'prev',
        );
      case AnalyticsRange.month:
        return AnalyticsBucketWindow(
          start: DateTime(start.year, start.month - 1, 1),
          end: start,
          label: 'prev',
        );
      case AnalyticsRange.threeMonths:
        return AnalyticsBucketWindow(
          start: DateTime(start.year, start.month - 3, 1),
          end: start,
          label: 'prev',
        );
    }
  }

  /// Builds the ordered list of buckets covering the period.
  List<AnalyticsBucketWindow> buckets([DateTime? now]) {
    final start = windowStart(now);
    final end = windowEnd(now);
    final result = <AnalyticsBucketWindow>[];

    if (bucket == AnalyticsBucket.day) {
      final dayFmt = this == AnalyticsRange.week
          ? DateFormat('EEE') // Mon, Tue …
          : DateFormat('d'); // 1 … 31
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
      // Monthly buckets for the quarter (3 of them).
      final monFmt = DateFormat('MMM'); // Apr, May, Jun
      var cursor = start;
      while (cursor.isBefore(end)) {
        final next = DateTime(cursor.year, cursor.month + 1, 1);
        result.add(AnalyticsBucketWindow(
          start: cursor,
          end: next,
          label: monFmt.format(cursor),
        ));
        cursor = next;
      }
    }
    return result;
  }
}
