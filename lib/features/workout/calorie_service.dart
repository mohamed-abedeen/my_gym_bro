/// Session calorie estimation.
///
/// Replaces the old flat "5 MET × body weight × wall-clock hours" estimate
/// with an ACSM/Compendium-style model:
///
///   kcal = Σ_exercise MET_ex × kg × activeHours_ex
///        + MET_rest × kg × restHours
///
/// Active time comes from the logged sets (cardio sets carry their own
/// duration; strength sets are assumed to take `assumedSetSeconds` under
/// load), so a dense 45-minute leg session now out-burns a chatty
/// 90-minute one. Sessions with no set data fall back to the legacy flat
/// model so old history keeps producing numbers.
library;

/// One exercise's contribution to a session: its MET intensity and how many
/// seconds of actual work it contained.
class ExerciseEffort {
  const ExerciseEffort({required this.met, required this.activeSeconds});
  final double met;
  final int activeSeconds;
}

class CalorieService {
  const CalorieService._();

  // ── MET table (Compendium of Physical Activities / ACSM) ────────────────

  /// Vigorous resistance work on big movers (squats, deadlifts, heavy
  /// pressing) — Compendium 02054 "resistance training, vigorous" ≈ 6.0.
  static const double largeMuscleMet = 6;

  /// Moderate resistance work — Compendium 02050 ≈ 4.5.
  static const double mediumMuscleMet = 4.5;

  /// Light/isolation resistance work — Compendium 02052 ≈ 3.5.
  static const double smallMuscleMet = 3.5;

  /// General vigorous cardio (running/rowing/HIIT mid-point) ≈ 8.0.
  static const double cardioMet = 8;

  /// Between-set standing/walking with elevated heart rate ≈ 2.0.
  static const double restMet = 2;

  /// Legacy flat MET used when a session has no set-level data.
  static const double fallbackMet = 5;

  /// Assumed seconds under load for a strength set without its own duration
  /// (a typical 8–12 rep working set).
  static const int assumedSetSeconds = 45;

  /// Multiplier applied for female users: at equal body weight, a lower
  /// lean-mass fraction burns slightly fewer calories during resistance
  /// exercise. Deliberately conservative.
  static const double femaleAdjustment = 0.95;

  /// Muscle groups whose compound work runs at [largeMuscleMet].
  static const _largeGroups = {
    'Quads',
    'Hamstrings',
    'Glutes',
    'Lower Back',
    'Chest',
    'Lats',
    'Upper Back',
  };

  /// Muscle groups at [mediumMuscleMet]; everything else is small/isolation.
  static const _mediumGroups = {'Shoulders', 'Traps', 'Triceps'};

  /// MET intensity for an exercise given its canonical muscle group.
  static double metForExercise({String? muscleGroup}) {
    if (muscleGroup == 'Cardio') return cardioMet;
    if (_largeGroups.contains(muscleGroup)) return largeMuscleMet;
    if (_mediumGroups.contains(muscleGroup)) return mediumMuscleMet;
    return smallMuscleMet;
  }

  /// Estimates the calories burned in one finished session.
  ///
  /// With [efforts], work time is billed at each exercise's MET and the
  /// remaining wall-clock time at [restMet]. If the logged work time
  /// exceeds the session duration (bad clocks, imported data), work is
  /// scaled down proportionally and rest contributes nothing. Without
  /// [efforts] the legacy flat model applies. [gender] 'female' applies
  /// [femaleAdjustment].
  static int estimateSessionCalories({
    required double bodyWeightKg,
    required int durationSeconds,
    List<ExerciseEffort> efforts = const [],
    String? gender,
  }) {
    if (durationSeconds <= 0 || bodyWeightKg <= 0) return 0;

    double kcal;
    if (efforts.isEmpty) {
      kcal = fallbackMet * bodyWeightKg * durationSeconds / 3600;
    } else {
      final totalActive =
          efforts.fold<int>(0, (sum, e) => sum + e.activeSeconds);
      final scale =
          totalActive > durationSeconds ? durationSeconds / totalActive : 1.0;

      var workKcal = 0.0;
      for (final e in efforts) {
        workKcal += e.met * bodyWeightKg * (e.activeSeconds * scale) / 3600;
      }
      final restSeconds = durationSeconds - totalActive * scale;
      kcal = workKcal + restMet * bodyWeightKg * restSeconds / 3600;
    }

    if (gender == 'female') kcal *= femaleAdjustment;
    return kcal.round();
  }
}
