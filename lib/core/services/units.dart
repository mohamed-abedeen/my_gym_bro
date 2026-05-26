import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

/// Precise kg <-> lb conversion factor (NIST: 1 kg = 2.20462262185 lb).
const double kLbsPerKg = 2.20462262185;

/// The supported weight units.
enum WeightUnit { kg, lbs }

WeightUnit weightUnitFromString(String? s) {
  return s == 'lbs' ? WeightUnit.lbs : WeightUnit.kg;
}

String weightUnitToString(WeightUnit u) => u == WeightUnit.lbs ? 'lbs' : 'kg';

String weightUnitLabel(WeightUnit u) => u == WeightUnit.lbs ? 'lbs' : 'kg';

/// Convert a kg value stored in the DB to the user's preferred display unit.
double convertFromKg(double kg, WeightUnit target) {
  return target == WeightUnit.lbs ? kg * kLbsPerKg : kg;
}

/// Convert a value entered in [source] unit back to kg (canonical storage).
double convertToKg(double value, WeightUnit source) {
  return source == WeightUnit.lbs ? value / kLbsPerKg : value;
}

/// Format a kg-stored weight for display in the user's current unit.
///
/// [decimals] controls precision. 1 decimal is the default — enough for gym
/// increments without noisy trailing zeros.
String formatWeight(
  double? kg,
  WeightUnit unit, {
  int decimals = 1,
  bool withUnit = false,
}) {
  if (kg == null) return withUnit ? '— ${weightUnitLabel(unit)}' : '—';
  final v = convertFromKg(kg, unit);
  final s = decimals == 0
      ? v.round().toString()
      : v.toStringAsFixed(decimals);
  // Strip trailing ".0" for clean integer display when applicable.
  final clean = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  return withUnit ? '$clean ${weightUnitLabel(unit)}' : clean;
}

/// Reactive provider for the user's preferred weight unit. Defaults to kg
/// while the profile is loading or absent.
final weightUnitProvider = Provider<WeightUnit>((ref) {
  final profile = ref.watch(userProfileProvider);
  return weightUnitFromString(
    profile.whenOrNull(data: (p) => p?.weightUnit),
  );
});
