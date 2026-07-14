/// Pure plate-loading math for the barbell plate calculator.
///
/// Greedy largest-first. That is exact for the standard sets below because
/// the smallest plate divides every larger one, so any residual that is a
/// multiple of the smallest plate always clears.
library;

/// Standard kg plate denominations, heaviest first.
const List<double> kKgPlates = [25, 20, 15, 10, 5, 2.5, 1.25];

/// Standard lbs plate denominations, heaviest first.
const List<double> kLbsPlates = [45, 35, 25, 10, 5, 2.5];

/// Default olympic bar weights.
const double kDefaultBarKg = 20;
const double kDefaultBarLbs = 45;

/// A plate denomination and how many of it to load per side.
typedef PlateCount = ({double plate, int count});

/// Result of [calculatePlates]. All values are in the caller's unit.
class PlateLoad {
  const PlateLoad({required this.platesPerSide, required this.remainder});

  /// Plates to load per side, heaviest first, counts > 0 only.
  final List<PlateCount> platesPerSide;

  /// Target minus achievable total weight. 0 when the load is exact,
  /// positive when the plate set can't reach the target, negative when the
  /// bar alone already exceeds it.
  final double remainder;
}

/// Which plates to load per side to hit [targetWeight] with [barWeight]
/// and the available [plates] denominations (unlimited count of each).
PlateLoad calculatePlates({
  required double targetWeight,
  required double barWeight,
  required List<double> plates,
}) {
  final sorted = [...plates]..sort((a, b) => b.compareTo(a));
  var perSide = (targetWeight - barWeight) / 2;
  final loaded = <PlateCount>[];
  if (perSide > 0) {
    for (final plate in sorted) {
      // Epsilon absorbs binary-float noise in user-entered decimals.
      final count = (perSide / plate + 1e-9).floor();
      if (count > 0) {
        loaded.add((plate: plate, count: count));
        perSide -= count * plate;
      }
    }
  }
  var loadedPerSide = 0.0;
  for (final p in loaded) {
    loadedPerSide += p.plate * p.count;
  }
  var remainder = targetWeight - barWeight - 2 * loadedPerSide;
  if (remainder.abs() < 1e-6) remainder = 0;
  return PlateLoad(platesPerSide: loaded, remainder: remainder);
}
