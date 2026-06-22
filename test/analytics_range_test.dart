import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_application_group/models/analytics_range.dart';

void main() {
  // Fixed "today" for deterministic calendar maths (22 June 2026).
  final now = DateTime(2026, 6, 22, 9, 0);

  group('Week range (Mon–Sun)', () {
    test('starts on Monday and spans exactly 7 days', () {
      final start = AnalyticsRange.week.windowStart(now);
      final end = AnalyticsRange.week.windowEnd(now);
      expect(start.weekday, DateTime.monday);
      expect(end.difference(start).inDays, 7);
    });

    test('has 7 daily buckets starting at Mon', () {
      final buckets = AnalyticsRange.week.buckets(now);
      expect(buckets.length, 7);
      expect(buckets.first.label, 'Mon');
      expect(buckets.last.label, 'Sun');
    });
  });

  group('Month range (from the 1st)', () {
    test('window is the whole current calendar month', () {
      expect(AnalyticsRange.month.windowStart(now), DateTime(2026, 6, 1));
      expect(AnalyticsRange.month.windowEnd(now), DateTime(2026, 7, 1));
    });

    test('has one bucket per day (June = 30)', () {
      expect(AnalyticsRange.month.buckets(now).length, 30);
    });

    test('subtitle names the month', () {
      expect(AnalyticsRange.month.windowSubtitle(now), 'June 2026');
    });
  });

  group('3-Month range (calendar quarter)', () {
    test('uses the quarter containing today (Apr–Jun)', () {
      expect(
          AnalyticsRange.threeMonths.windowStart(now), DateTime(2026, 4, 1));
      expect(AnalyticsRange.threeMonths.windowEnd(now), DateTime(2026, 7, 1));
    });

    test('is bucketed per month with 3 buckets', () {
      final buckets = AnalyticsRange.threeMonths.buckets(now);
      expect(buckets.length, 3);
      expect(buckets.map((b) => b.label).toList(), ['Apr', 'May', 'Jun']);
    });

    test('subtitle spans the quarter', () {
      expect(AnalyticsRange.threeMonths.windowSubtitle(now), 'Apr–Jun 2026');
    });

    test('previous window is the prior quarter (Jan–Mar)', () {
      final prev = AnalyticsRange.threeMonths.previousWindow(now);
      expect(prev.start, DateTime(2026, 1, 1));
      expect(prev.end, DateTime(2026, 4, 1));
    });
  });

  test('quarter detection handles year edges', () {
    expect(AnalyticsRange.threeMonths.windowStart(DateTime(2026, 1, 15)),
        DateTime(2026, 1, 1));
    expect(AnalyticsRange.threeMonths.windowStart(DateTime(2026, 12, 31)),
        DateTime(2026, 10, 1));
    // Previous quarter of Q1 crosses into the prior year.
    expect(AnalyticsRange.threeMonths.previousWindow(DateTime(2026, 2, 1)).start,
        DateTime(2025, 10, 1));
  });
}
