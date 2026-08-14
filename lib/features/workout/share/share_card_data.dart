import 'package:my_gym_bro/features/exercises/lift_rank/strength_standards.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart'
    show EnrichedSession, epleyOneRepMax;

/// One performed exercise as it appears on a share card: its name and how
/// many sets were actually completed.
class ShareExercise {
  const ShareExercise({required this.name, required this.sets});

  final String name;
  final int sets;
}

/// A classic lift's rank as performed THIS session — the session-best e1RM
/// run through the strength standards, not the all-time rank (the card is a
/// per-session snapshot).
class ShareLiftRank {
  const ShareLiftRank({
    required this.name,
    required this.band,
    required this.e1RmKg,
  });

  final String name;

  /// 15-band ladder position — feed to [Rank.fromBand].
  final int band;

  /// Session-best estimated 1RM (kg) behind the rank.
  final double e1RmKg;
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
    this.liftRanks = const [],
    this.date,
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
    double? bodyWeightKg,
    String? gender,
  }) {
    final exercises = <ShareExercise>[];
    final workedMuscleGroups = <String>{};
    final liftRanks = <ShareLiftRank>[];
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
        _addLiftRank(liftRanks, ex.exerciseId, ex.name, best,
            bodyWeightKg: bodyWeightKg, gender: gender);
      }
    }
    _sortLiftRanks(liftRanks);
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
      liftRanks: liftRanks,
      date: state.startedAt ?? DateTime.now(),
    );
  }

  /// Builds a card snapshot from a persisted session in the history list.
  /// Same shape as `fromActiveSession`, sourced from the enriched DB rows.
  /// `workoutNumber` stays 0 (the card hides it) — the history list can be
  /// reordered by the date jump, so an index-derived "#N" would lie.
  factory ShareCardData.fromEnrichedSession(
    EnrichedSession enriched, {
    bool hasPr = false,
    double? bodyWeightKg,
    String? gender,
  }) {
    final exercises = <ShareExercise>[];
    final workedMuscleGroups = <String>{};
    final liftRanks = <ShareLiftRank>[];
    var e1rmSum = 0.0;
    var e1rmCount = 0;
    var totalSets = 0;
    for (final ex in enriched.exercises) {
      if (ex.sets == 0) continue;
      exercises.add(ShareExercise(name: ex.name, sets: ex.sets));
      totalSets += ex.sets;
      final mg = ex.muscleGroup;
      if (mg != null && mg.toLowerCase() != 'cardio') {
        workedMuscleGroups.add(mg);
      }

      var best = 0.0;
      for (final s in ex.setDetails) {
        if (s.isWarmup) continue;
        final w = s.weight;
        final r = s.reps;
        if (w == null || r == null || w <= 0 || r <= 0) continue;
        final e = epleyOneRepMax(w, r);
        if (e > best) best = e;
      }
      if (best > 0) {
        e1rmSum += best;
        e1rmCount++;
        _addLiftRank(liftRanks, ex.exerciseId, ex.name, best,
            bodyWeightKg: bodyWeightKg, gender: gender);
      }
    }
    _sortLiftRanks(liftRanks);
    return ShareCardData(
      workoutName: enriched.workoutName,
      totalVolumeKg: enriched.session.totalVolume ?? 0,
      totalSets: totalSets,
      durationSeconds: enriched.session.durationSeconds ?? 0,
      avgStrength: e1rmCount == 0 ? 0 : e1rmSum / e1rmCount,
      workoutNumber: 0,
      exercises: exercises,
      workedMuscleGroups: workedMuscleGroups,
      hasPr: hasPr,
      liftRanks: liftRanks,
      date: enriched.session.startedAt,
    );
  }

  /// Appends the lift's session rank when it's a rankable classic and the
  /// caller supplied a bodyweight (no bodyweight → no ratio → no rank row).
  static void _addLiftRank(
    List<ShareLiftRank> ranks,
    String exerciseId,
    String name,
    double e1RmKg, {
    double? bodyWeightKg,
    String? gender,
  }) {
    if (bodyWeightKg == null) return;
    final score = liftScore(
      exerciseId: exerciseId,
      e1RmKg: e1RmKg,
      bodyWeightKg: bodyWeightKg,
      gender: gender,
    );
    if (score == null) return;
    ranks.add(ShareLiftRank(
      name: name,
      band: Rank.fromComposite(score).band,
      e1RmKg: e1RmKg,
    ));
  }

  /// Highest band first (ties: heavier e1RM first) — the card's hero is
  /// simply `liftRanks.first`.
  static void _sortLiftRanks(List<ShareLiftRank> ranks) {
    ranks.sort((a, b) {
      final byBand = b.band.compareTo(a.band);
      return byBand != 0 ? byBand : b.e1RmKg.compareTo(a.e1RmKg);
    });
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

  /// Session ranks for the classic lifts performed (highest band first).
  /// Empty when none were trained or no bodyweight was available — the
  /// "Ranks" share template is only offered when this is non-empty.
  final List<ShareLiftRank> liftRanks;

  /// When the workout happened — the date line on the cards. Null only in
  /// hand-built test data; cards fall back to "now".
  final DateTime? date;
}
