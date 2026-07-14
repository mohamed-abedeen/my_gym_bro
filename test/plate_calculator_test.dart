import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/workout/plate_calculator.dart';

void main() {
  group('calculatePlates — kg', () {
    test('exact load: 100 kg on a 20 kg bar', () {
      final load = calculatePlates(
        targetWeight: 100,
        barWeight: kDefaultBarKg,
        plates: kKgPlates,
      );
      expect(load.platesPerSide, [(plate: 25.0, count: 1), (plate: 15.0, count: 1)]);
      expect(load.remainder, 0);
    });

    test('multiple of the same plate: 170 kg → 25 × 3 per side', () {
      final load = calculatePlates(
        targetWeight: 170,
        barWeight: kDefaultBarKg,
        plates: kKgPlates,
      );
      expect(load.platesPerSide, [(plate: 25.0, count: 3)]);
      expect(load.remainder, 0);
    });

    test('microplates: 102.5 kg uses the 1.25', () {
      final load = calculatePlates(
        targetWeight: 102.5,
        barWeight: kDefaultBarKg,
        plates: kKgPlates,
      );
      expect(load.platesPerSide, [
        (plate: 25.0, count: 1),
        (plate: 15.0, count: 1),
        (plate: 1.25, count: 1),
      ]);
      expect(load.remainder, 0);
    });

    test('unreachable remainder: 101 kg is off by 1 kg', () {
      final load = calculatePlates(
        targetWeight: 101,
        barWeight: kDefaultBarKg,
        plates: kKgPlates,
      );
      expect(load.platesPerSide, [(plate: 25.0, count: 1), (plate: 15.0, count: 1)]);
      expect(load.remainder, closeTo(1, 1e-9));
    });

    test('bar alone heavier than target: negative remainder, no plates', () {
      final load = calculatePlates(
        targetWeight: 15,
        barWeight: kDefaultBarKg,
        plates: kKgPlates,
      );
      expect(load.platesPerSide, isEmpty);
      expect(load.remainder, -5);
    });

    test('target equals bar: empty bar, exact', () {
      final load = calculatePlates(
        targetWeight: 20,
        barWeight: kDefaultBarKg,
        plates: kKgPlates,
      );
      expect(load.platesPerSide, isEmpty);
      expect(load.remainder, 0);
    });

    test('custom bar weight: 55 kg on a 15 kg bar', () {
      final load = calculatePlates(
        targetWeight: 55,
        barWeight: 15,
        plates: kKgPlates,
      );
      expect(load.platesPerSide, [(plate: 20.0, count: 1)]);
      expect(load.remainder, 0);
    });

    test('custom plate set: only 10s and 5s', () {
      final load = calculatePlates(
        targetWeight: 47,
        barWeight: kDefaultBarKg,
        plates: const [10, 5],
      );
      expect(load.platesPerSide, [(plate: 10.0, count: 1)]);
      expect(load.remainder, closeTo(7, 1e-9));
    });

    test('unsorted plate list still loads heaviest first', () {
      final load = calculatePlates(
        targetWeight: 100,
        barWeight: kDefaultBarKg,
        plates: const [1.25, 25, 2.5, 20, 5, 15, 10],
      );
      expect(load.platesPerSide, [(plate: 25.0, count: 1), (plate: 15.0, count: 1)]);
      expect(load.remainder, 0);
    });
  });

  group('calculatePlates — lbs', () {
    test('two plates: 225 lbs on a 45 lbs bar', () {
      final load = calculatePlates(
        targetWeight: 225,
        barWeight: kDefaultBarLbs,
        plates: kLbsPlates,
      );
      expect(load.platesPerSide, [(plate: 45.0, count: 2)]);
      expect(load.remainder, 0);
    });

    test('classic 135 lbs: one 45 per side', () {
      final load = calculatePlates(
        targetWeight: 135,
        barWeight: kDefaultBarLbs,
        plates: kLbsPlates,
      );
      expect(load.platesPerSide, [(plate: 45.0, count: 1)]);
      expect(load.remainder, 0);
    });

    test('mixed denominations: 190 lbs on a 35 lbs bar', () {
      // Per side 77.5 → 45 + 25 + 5 + 2.5.
      final load = calculatePlates(
        targetWeight: 190,
        barWeight: 35,
        plates: kLbsPlates,
      );
      expect(load.platesPerSide, [
        (plate: 45.0, count: 1),
        (plate: 25.0, count: 1),
        (plate: 5.0, count: 1),
        (plate: 2.5, count: 1),
      ]);
      expect(load.remainder, 0);
    });

    test('unreachable remainder: 137 lbs is off by 2', () {
      final load = calculatePlates(
        targetWeight: 137,
        barWeight: kDefaultBarLbs,
        plates: kLbsPlates,
      );
      expect(load.platesPerSide, [(plate: 45.0, count: 1)]);
      expect(load.remainder, closeTo(2, 1e-9));
    });
  });
}
