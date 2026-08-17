import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

/// Which per-session trend the progress chart shows (PRD §5.12).
enum ProgressMetric { volume, topSet, e1rm }

/// One finished session's numbers for an exercise. All values are kg.
class ExerciseProgressPoint {
  const ExerciseProgressPoint({
    required this.date,
    required this.volume,
    required this.topSetWeight,
    required this.e1rm,
  });

  final DateTime date;

  /// Σ weight × reps over the session's logged sets (same semantics as
  /// [SessionDao.getVolumeHistoryForExercise]).
  final double volume;

  /// Heaviest set of the session.
  final double topSetWeight;

  /// Best Epley estimated 1RM across the session's sets.
  final double e1rm;

  double valueFor(ProgressMetric metric) => switch (metric) {
        ProgressMetric.volume => volume,
        ProgressMetric.topSet => topSetWeight,
        ProgressMetric.e1rm => e1rm,
      };
}

/// Collapses an exercise's session history (newest-first, as
/// [SessionDao.getSessionsForExercise] returns it) into chart points,
/// oldest → newest. Sets missing weight or reps are ignored — mirroring the
/// DAO's volume-history query — and sessions with no usable sets are
/// skipped entirely rather than plotted as zero dips.
List<ExerciseProgressPoint> buildProgressPoints(
  List<ExerciseHistoryEntry> history,
) {
  final points = <ExerciseProgressPoint>[];
  for (final entry in history.reversed) {
    var volume = 0.0;
    var top = 0.0;
    var e1rm = 0.0;
    var usable = false;
    for (final set in entry.sets) {
      final weight = set.weight;
      final reps = set.reps;
      if (weight == null || reps == null) continue;
      usable = true;
      volume += weight * reps;
      if (weight > top) top = weight;
      final e = epleyOneRepMax(weight, reps);
      if (e > e1rm) e1rm = e;
    }
    if (!usable) continue;
    points.add(ExerciseProgressPoint(
      date: entry.session.startedAt,
      volume: volume,
      topSetWeight: top,
      e1rm: e1rm,
    ));
  }
  return points;
}

/// Exercises with enough history to chart (≥ 2 finished sessions), most
/// logged first — the progress section's picker row.
final chartableExercisesProvider =
    FutureProvider.autoDispose<List<ChartableExercise>>(
  (ref) => ref.watch(sessionDaoProvider).getMostLoggedExercises(),
);

/// Per-session progress points for one exercise, oldest → newest.
final exerciseProgressProvider = FutureProvider.autoDispose
    .family<List<ExerciseProgressPoint>, String>((ref, exerciseId) async {
  final history =
      await ref.watch(sessionDaoProvider).getSessionsForExercise(exerciseId);
  return buildProgressPoints(history);
});
