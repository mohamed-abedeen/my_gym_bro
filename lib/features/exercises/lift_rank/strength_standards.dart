/// Strength-standard tables for the classic barbell lifts, used to place a
/// lift's estimated 1RM on the Bronze→Elite ladder (`Rank.fromComposite`).
///
/// A lift's score is the bodyweight ratio (e1RM ÷ bodyweight, both kg) run
/// through six per-sex anchor ratios mapping to scores 0/20/40/60/80/100,
/// piecewise-linear between anchors and clamped at both ends — so Bronze III
/// is the floor and score 100 is Elite I. The anchor values are our own
/// approximations of commonly cited strength standards (no licensed data).
library;

class _Standard {
  const _Standard({required this.male, required this.female});

  /// Six ascending bodyweight ratios at scores 0, 20, 40, 60, 80, 100.
  final List<double> male;
  final List<double> female;
}

/// Keyed by the ExerciseDB `exerciseId` string — the app-wide business key
/// that sessions and schedules join on. Ids match `assets/exercises_starter.json`.
const Map<String, _Standard> _standards = {
  // Barbell bench press
  'EIeI8Vf': _Standard(
    male: [0.50, 0.75, 1.10, 1.50, 1.90, 2.25],
    female: [0.30, 0.45, 0.70, 1.00, 1.30, 1.60],
  ),
  // Barbell full squat
  'qXTaZnJ': _Standard(
    male: [0.75, 1.00, 1.50, 2.00, 2.50, 3.00],
    female: [0.50, 0.75, 1.15, 1.55, 2.00, 2.40],
  ),
  // Barbell deadlift
  'ila4NZS': _Standard(
    male: [1.00, 1.25, 1.75, 2.25, 2.75, 3.25],
    female: [0.60, 0.90, 1.30, 1.75, 2.25, 2.70],
  ),
  // Barbell seated overhead press
  'kTbSH9h': _Standard(
    male: [0.35, 0.55, 0.75, 1.00, 1.25, 1.50],
    female: [0.25, 0.40, 0.55, 0.75, 0.95, 1.15],
  ),
  // Barbell bent over row
  'eZyBC3j': _Standard(
    male: [0.50, 0.70, 0.95, 1.25, 1.55, 1.80],
    female: [0.35, 0.50, 0.70, 0.95, 1.20, 1.40],
  ),
};

/// Whether [exerciseId] has a strength-standard table (i.e. can be ranked).
bool isRankableLift(String exerciseId) => _standards.containsKey(exerciseId);

/// 0–100 rank score for a lift, or null when the exercise has no table or
/// the inputs can't produce a ratio. Any [gender] other than 'female'
/// (including null) uses the male table, matching `userGenderProvider`.
double? liftScore({
  required String exerciseId,
  required double e1RmKg,
  required double bodyWeightKg,
  String? gender,
}) {
  final standard = _standards[exerciseId];
  if (standard == null || e1RmKg <= 0 || bodyWeightKg <= 0) return null;
  final anchors = gender == 'female' ? standard.female : standard.male;
  final ratio = e1RmKg / bodyWeightKg;
  if (ratio <= anchors.first) return 0;
  if (ratio >= anchors.last) return 100;
  var i = 1;
  while (ratio > anchors[i]) {
    i++;
  }
  final lo = anchors[i - 1];
  final hi = anchors[i];
  return ((i - 1) + (ratio - lo) / (hi - lo)) * 20;
}
