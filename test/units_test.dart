import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/services/units.dart';

void main() {
  group('weightUnitFromString', () {
    test('returns lbs for "lbs"', () {
      expect(weightUnitFromString('lbs'), WeightUnit.lbs);
    });

    test('returns kg for "kg"', () {
      expect(weightUnitFromString('kg'), WeightUnit.kg);
    });

    test('returns kg for null', () {
      expect(weightUnitFromString(null), WeightUnit.kg);
    });

    test('returns kg for unknown string', () {
      expect(weightUnitFromString('pounds'), WeightUnit.kg);
    });
  });

  group('convertFromKg', () {
    test('returns kg value unchanged when target is kg', () {
      expect(convertFromKg(100, WeightUnit.kg), 100.0);
    });

    test('converts kg to lbs correctly', () {
      final result = convertFromKg(1, WeightUnit.lbs);
      expect(result, closeTo(2.20462, 0.00001));
    });

    test('converts 100 kg to lbs', () {
      final result = convertFromKg(100, WeightUnit.lbs);
      expect(result, closeTo(220.462, 0.001));
    });

    test('handles zero', () {
      expect(convertFromKg(0, WeightUnit.lbs), 0.0);
    });
  });

  group('convertToKg', () {
    test('returns value unchanged when source is kg', () {
      expect(convertToKg(100, WeightUnit.kg), 100.0);
    });

    test('converts lbs to kg correctly', () {
      final result = convertToKg(2.20462262185, WeightUnit.lbs);
      expect(result, closeTo(1.0, 0.000001));
    });

    test('roundtrip kg → lbs → kg stays within 0.01 kg', () {
      const original = 80.0;
      final inLbs = convertFromKg(original, WeightUnit.lbs);
      final backToKg = convertToKg(inLbs, WeightUnit.lbs);
      expect(backToKg, closeTo(original, 0.01));
    });
  });

  group('formatWeight', () {
    test('formats kg value with one decimal', () {
      expect(formatWeight(80, WeightUnit.kg), '80');
    });

    test('formats kg value with non-zero decimal', () {
      expect(formatWeight(80.5, WeightUnit.kg), '80.5');
    });

    test('appends unit when withUnit is true', () {
      expect(formatWeight(80, WeightUnit.kg, withUnit: true), '80 kg');
    });

    test('formats lbs conversion', () {
      // 1 kg ≈ 2.2 lbs
      final result = formatWeight(1, WeightUnit.lbs);
      expect(result, '2.2');
    });

    test('returns dash for null kg', () {
      expect(formatWeight(null, WeightUnit.kg), '—');
    });

    test('returns dash with unit for null kg and withUnit true', () {
      expect(formatWeight(null, WeightUnit.kg, withUnit: true), '— kg');
    });

    test('strips trailing .0 for whole-number result', () {
      expect(formatWeight(50, WeightUnit.kg), '50');
    });

    test('respects custom decimals', () {
      expect(formatWeight(80.123, WeightUnit.kg, decimals: 2), '80.12');
    });
  });
}
