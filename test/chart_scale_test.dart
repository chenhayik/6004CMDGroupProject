import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_application_group/views/analytics/chart_scale.dart';

void main() {
  group('niceInterval', () {
    test('picks rounded 1/2/2.5/5 × 10ⁿ steps', () {
      expect(niceInterval(40), 10);
      expect(niceInterval(4), 1);
      expect(niceInterval(2000), 500);
    });

    test('is safe for zero/negative', () {
      expect(niceInterval(0), 1);
      expect(niceInterval(-5), 1);
    });
  });

  group('niceAxis (0-based bar charts)', () {
    test('protein-sized values → 0..200 step 50', () {
      final a = niceAxis(150);
      expect(a.interval, 50);
      expect(a.max, 200);
    });

    test('always leaves headroom above the data max', () {
      for (final raw in [1.0, 17.0, 150.0, 2000.0, 4800.0]) {
        final a = niceAxis(raw);
        expect(a.max, greaterThan(raw));
        // Max is a whole multiple of the interval.
        expect((a.max % a.interval).abs(), lessThan(1e-9));
      }
    });

    test('zero data still yields a usable axis', () {
      final a = niceAxis(0);
      expect(a.max, greaterThan(0));
      expect(a.interval, greaterThan(0));
    });
  });

  group('niceRange (non-zero-based, e.g. 1RM)', () {
    test('expands outward to rounded gridlines', () {
      final r = niceRange(80, 120);
      expect(r.min, lessThanOrEqualTo(80));
      expect(r.max, greaterThanOrEqualTo(120));
      expect(r.interval, greaterThan(0));
    });

    test('degenerate (flat line) still gives a band', () {
      final r = niceRange(100, 100);
      expect(r.max, greaterThan(r.min));
    });
  });
}
