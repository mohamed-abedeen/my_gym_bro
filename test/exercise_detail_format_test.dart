import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/exercises/exercise_detail_format.dart';

/// Pure helpers behind the redesigned exercise detail screen.
void main() {
  group('titleCase', () {
    test('capitalises every word of a lowercase catalogue name', () {
      expect(titleCase('barbell bench press'), 'Barbell Bench Press');
      expect(titleCase('Already Cased'), 'Already Cased');
      expect(titleCase(''), '');
    });
  });

  group('stripStepPrefix', () {
    test('drops the catalogue Step:N prefix and keeps the text', () {
      expect(
        stripStepPrefix('Step:1 Lie flat on the bench.'),
        'Lie flat on the bench.',
      );
      expect(stripStepPrefix('Step:12   Lower the bar.'), 'Lower the bar.');
      expect(stripStepPrefix('Lower the bar.'), 'Lower the bar.');
    });
  });

  group('highlightedBars', () {
    test('marks running PRs and the latest session', () {
      // 100 (first -> PR), 90, 120 (PR), 110, 115 (latest).
      expect(
        highlightedBars([100, 90, 120, 110, 115]),
        [true, false, true, false, true],
      );
    });

    test('handles empty and single-session windows', () {
      expect(highlightedBars([]), isEmpty);
      expect(highlightedBars([50]), [true]);
    });

    test('matching the record is not a new PR', () {
      expect(highlightedBars([100, 100, 80]), [true, false, true]);
    });
  });

  group('prBarIndex', () {
    test('points at the first occurrence of the window maximum', () {
      expect(prBarIndex([100, 120, 120, 90]), 1);
      expect(prBarIndex([]), -1);
    });
  });

  group('compactVolume', () {
    test('shows tonnes with one decimal from 1000 kg', () {
      expect(compactVolume(4200, WeightUnit.kg), (value: '4.2', unit: 't'));
      expect(compactVolume(800, WeightUnit.kg), (value: '800', unit: 'kg'));
    });

    test('switches to thousands in lbs', () {
      // 4200 kg = 9259 lbs; 400 kg = 882 lbs.
      expect(
        compactVolume(4200, WeightUnit.lbs),
        (value: '9.3', unit: 'k lbs'),
      );
      expect(compactVolume(400, WeightUnit.lbs), (value: '882', unit: 'lbs'));
    });
  });

  group('axisLabel', () {
    test('formats ticks in thousands from 1000 and drops a trailing .0', () {
      expect(axisLabel(4200, WeightUnit.kg), '4.2k');
      expect(axisLabel(2100, WeightUnit.kg), '2.1k');
      expect(axisLabel(2000, WeightUnit.kg), '2k');
      expect(axisLabel(800, WeightUnit.kg), '800');
      expect(axisLabel(0, WeightUnit.kg), '0');
    });
  });

  group('monthTicks', () {
    test('collapses dates to distinct months, oldest first', () {
      final ticks = monthTicks([
        DateTime(2026, 6, 3),
        DateTime(2026, 6, 20),
        DateTime(2026, 7),
        DateTime(2026, 9, 6),
      ]);
      expect(ticks, [DateTime(2026, 6), DateTime(2026, 7), DateTime(2026, 9)]);
    });

    test('thins long spans, keeping the first and last month', () {
      final dates = [for (var m = 1; m <= 12; m++) DateTime(2026, m, 15)];
      final ticks = monthTicks(dates, maxTicks: 4);
      expect(ticks, hasLength(4));
      expect(ticks.first, DateTime(2026));
      expect(ticks.last, DateTime(2026, 12));
    });
  });
}
