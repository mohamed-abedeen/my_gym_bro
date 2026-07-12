import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart'
    show epleyOneRepMax;

/// One performed exercise as it appears on a share card: its name and how
/// many sets were actually completed.
class ShareExercise {
  const ShareExercise({required this.name, required this.sets});

  final String name;
  final int sets;
}

/// Immutable snapshot of a finished workout, shaped for rendering a share
/// card. Built once from the live [ActiveSessionState] via
/// [ShareCardData.fromActiveSession] so templates never touch mutable
/// session state. Every stat is for THIS session — a post-workout card shows
/// the workout you just did, not weekly/lifetime aggregates.
class ShareCardData {
  const ShareCardData({
    required this.workoutName,
    required this.totalVolumeKg,
    required this.totalSets,
    required this.durationSeconds,
    required this.avgStrength,
    required this.workoutNumber,
    required this.exercises,
    required this.workedMuscleGroups,
    required this.hasPr,
  });

  /// Builds a card snapshot from the live session state. Exercises with no
  /// completed sets are dropped, and `workedMuscleGroups` is derived from the
  /// same performed set so the anatomy highlight matches the exercise list.
  /// [avgStrength] is the mean best estimated 1RM across this session's
  /// exercises (completed, non-warmup sets only) — the same measure the app's
  /// weekly stats use, but scoped to this workout.
  factory ShareCardData.fromActiveSession(
    ActiveSessionState state, {
    required String workoutName,
    required int workoutNumber,
  }) {
    final exercises = <ShareExercise>[];
    final workedMuscleGroups = <String>{};
    var e1rmSum = 0.0;
    var e1rmCount = 0;
    for (final ex in state.exercises) {
      final completed = ex.sets.where((s) => s.isCompleted).length;
      if (completed == 0) continue;
      exercises.add(ShareExercise(name: ex.name, sets: completed));
      final mg = ex.muscleGroup;
      if (mg != null && !ex.isCardio) workedMuscleGroups.add(mg);

      // Best estimated 1RM for this exercise this session.
      var best = 0.0;
      for (final s in ex.sets) {
        if (!s.isCompleted || s.isWarmup) continue;
        final w = s.weight;
        final r = s.reps;
        if (w == null || r == null || w <= 0 || r <= 0) continue;
        final e = epleyOneRepMax(w, r);
        if (e > best) best = e;
      }
      if (best > 0) {
        e1rmSum += best;
        e1rmCount++;
      }
    }
    return ShareCardData(
      workoutName: workoutName,
      totalVolumeKg: state.totalVolume,
      totalSets: state.totalCompletedSets,
      durationSeconds: state.elapsedSeconds,
      avgStrength: e1rmCount == 0 ? 0 : e1rmSum / e1rmCount,
      workoutNumber: workoutNumber,
      exercises: exercises,
      workedMuscleGroups: workedMuscleGroups,
      hasPr: state.prEvent != null,
    );
  }

  /// Derived title, e.g. "Chest Day" (see `deriveWorkoutName`).
  final String workoutName;

  /// This session's completed-set volume in kg (canonical unit). Convert for
  /// display via `convertFromKg` / `formatWeight`.
  final double totalVolumeKg;

  /// This session's completed sets.
  final int totalSets;

  /// This session's elapsed (working) duration in seconds.
  final int durationSeconds;

  /// This session's mean best estimated 1RM (kg) across its exercises. 0 when
  /// the session had no weighted working sets.
  final double avgStrength;

  /// The Nth workout this represents (for "Workout #N"). 0 when unknown.
  final int workoutNumber;

  /// Only exercises with at least one completed set, in session order.
  final List<ShareExercise> exercises;

  /// Muscle groups worked (non-cardio, from performed exercises) — feeds the
  /// anatomy highlight.
  final Set<String> workedMuscleGroups;

  final bool hasPr;
}
