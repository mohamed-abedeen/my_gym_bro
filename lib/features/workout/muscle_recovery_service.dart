import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/services/exercise_mapping.dart';
import 'package:my_gym_bro/shared/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Muscle State Enum
// ─────────────────────────────────────────────────────────────────────────────

/// The three lifecycle phases of a muscle after training.
///
/// ```text
///  WORKOUT ──► recovering (0 → recoveryHours)
///          ──► recovered  (recoveryHours → 168 h / 7 days)
///          ──► undertrained (> 168 h  OR  never trained)
/// ```
enum MuscleState { recovered, recovering, undertrained }

// ─────────────────────────────────────────────────────────────────────────────
// Muscle Size Classification
// ─────────────────────────────────────────────────────────────────────────────

/// Categorises muscles by physiological size, which determines base recovery
/// time. Backed by exercise-science consensus (Schoenfeld et al., 2016;
/// NSCA guidelines).
enum MuscleSize {
  /// Large compound movers — high CNS load, dense fibre volume.
  /// Base recovery: **48–72 h** (we use 60 h midpoint).
  large(baseRecoveryHours: 60),

  /// Mid-size movers — moderate fibre volume, moderate CNS demand.
  /// Base recovery: **36–48 h** (we use 42 h midpoint).
  medium(baseRecoveryHours: 42),

  /// Small / stabiliser muscles — low total volume, fast turnover.
  /// Base recovery: **24–36 h** (we use 30 h midpoint).
  small(baseRecoveryHours: 30);

  const MuscleSize({required this.baseRecoveryHours});
  final double baseRecoveryHours;
}

// ─────────────────────────────────────────────────────────────────────────────
// Muscle State Info (public model)
// ─────────────────────────────────────────────────────────────────────────────

class MuscleStateInfo {
  const MuscleStateInfo({
    required this.muscleGroup,
    required this.state,
    this.lastTrainedAt,
    this.recoveryPercent,
    this.recoveryHours,
  });
  final String muscleGroup;
  final MuscleState state;
  final DateTime? lastTrainedAt;

  /// **Recovery progress**: 0.0 = just trained → 1.0 = fully recovered.
  /// Stays at 1.0 during the "trained & retained" window.
  /// Null when never trained (undertrained).
  final double? recoveryPercent;

  /// Total recovery window (hours) for the latest training bout, after
  /// dose scaling and fatigue stacking. Null when never trained. Falls
  /// back to the muscle's base hours where callers need a duration.
  final double? recoveryHours;

  /// When the muscle is (or was) fully recovered from its latest bout.
  /// Null when never trained.
  DateTime? get recoveredAt {
    final trained = lastTrainedAt;
    if (trained == null) return null;
    final hours =
        recoveryHours ?? MuscleRecoveryService.recoveryHoursFor(muscleGroup);
    return trained.add(Duration(minutes: (hours * 60).round()));
  }

  /// Legacy alias — some UI code reads `soreness`.
  /// Soreness is the inverse of recovery: 1.0 = just trained, 0.0 = recovered.
  double? get soreness =>
      recoveryPercent == null ? null : (1.0 - recoveryPercent!).clamp(0.0, 1.0);

  /// Colour that maps to the current state:
  ///
  /// | State        | Colour                                         |
  /// |--------------|-------------------------------------------------|
  /// | Undertrained | `AppColors.muscleUntrained` (grey)              |
  /// | Recovering   | Red → Amber → Green gradient based on progress  |
  /// | Recovered    | Solid green (`AppColors.success`)               |
  Color get color {
    if (state == MuscleState.undertrained || recoveryPercent == null) {
      return AppColors.muscleUntrained;
    }

    // Fully recovered / trained-and-retained → solid green
    if (state == MuscleState.recovered) return AppColors.success;

    // Recovering: gradient from red (0%) through amber (50%) to green (100%)
    final p = recoveryPercent!.clamp(0.0, 1.0);

    if (p >= 1.0) return AppColors.success;

    if (p >= 0.5) {
      // Amber → Green
      final t = (p - 0.5) / 0.5;
      return Color.lerp(AppColors.amber, AppColors.success, t)!;
    } else {
      // Red → Amber
      final t = p / 0.5;
      return Color.lerp(AppColors.danger, AppColors.amber, t)!;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Muscle Recovery Service
// ─────────────────────────────────────────────────────────────────────────────

/// A single training bout for one muscle group: when it happened and how
/// hard it hit the muscle (in weighted working sets).
@visibleForTesting
class MuscleDoseEvent {
  const MuscleDoseEvent({required this.trainedAt, required this.dose});
  final DateTime trainedAt;

  /// Weighted working-set count: primary-muscle sets count 1.0 each,
  /// secondary-muscle sets count [MuscleRecoveryService.secondaryMuscleCredit].
  final double dose;
}

/// The dose-adjusted recovery outcome for a muscle's latest bout.
@visibleForTesting
class MuscleRecoveryWindow {
  const MuscleRecoveryWindow({
    required this.lastTrainedAt,
    required this.recoveryHours,
  });
  final DateTime lastTrainedAt;
  final double recoveryHours;
}

class MuscleRecoveryService {
  MuscleRecoveryService(this._sessionDao, this._exerciseDao);
  final SessionDao _sessionDao;
  final ExerciseDao _exerciseDao;

  // ── Canonical muscle group list ──────────────────────────────────────────

  static const _allMuscleGroups = [
    'Chest',
    'Lats',
    'Upper Back',
    'Lower Back',
    'Traps',
    'Shoulders',
    'Front Delt',
    'Side Delt',
    'Rear Delt',
    'Biceps',
    'Triceps',
    'Forearms',
    'Quads',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Core',
    'Neck',
    'Cardio',
  ];

  // ── Research-backed recovery hours per muscle group ──────────────────────
  //
  // Sources:
  //   • Schoenfeld, B.J. (2016) — "Science and Development of Muscle
  //     Hypertrophy"
  //   • NSCA Essentials of Strength Training & Conditioning, 4th ed.
  //   • Damas, F. et al. (2015) — Muscle damage / recovery meta-analysis
  //
  // Large muscles (high CNS load, dense fibre volume) ≈ 48–72 h
  // Medium muscles (moderate volume)                  ≈ 36–48 h
  // Small muscles (low total volume, fast turnover)   ≈ 24–36 h
  // ────────────────────────────────────────────────────────────────────────

  static const _muscleSizeMap = <String, MuscleSize>{
    // ── Large ──
    'Chest': MuscleSize.large, // pectorals — heavy compound pressing
    'Lats': MuscleSize.large, // latissimus dorsi — wide, dense
    'Upper Back': MuscleSize.large, // rhomboids + mid-traps — compound rows
    'Lower Back': MuscleSize.large, // erector spinae — high CNS fatigue
    'Quads': MuscleSize.large, // quadriceps — largest muscle group
    'Hamstrings': MuscleSize.large, // biceps femoris + semis
    'Glutes': MuscleSize.large, // gluteus maximus — biggest single muscle
    // ── Medium ──
    'Shoulders': MuscleSize.medium, // 3-head deltoid (catch-all / unclassified)
    // ── Deltoid sub-groups (individual heads) ──
    'Front Delt': MuscleSize.small, // anterior deltoid
    'Side Delt': MuscleSize.small, // lateral deltoid
    'Rear Delt': MuscleSize.small, // posterior deltoid
    'Traps': MuscleSize.medium, // upper traps — heavy shrugs / carries
    'Triceps': MuscleSize.medium, // 3-head, moderate volume
    // ── Small ──
    'Biceps': MuscleSize.small, // 2-head, small cross-section
    'Forearms': MuscleSize.small, // brachioradialis + grip extensors
    'Calves': MuscleSize.small, // soleus + gastrocnemius, fast-twitch
    'Core': MuscleSize.small, // rectus abdominis + obliques
    'Neck': MuscleSize.small, // sternocleidomastoid + upper traps
    'Cardio': MuscleSize.small, // cardiovascular — minimal DOMS
  };

  /// The "trained & retained" window. After full recovery, the muscle stays
  /// green for this long before fading to untrained (grey). 168h = 7 days
  /// — matches the lifecycle docstring at the top of this file and the
  /// research-backed "use it or lose it" detraining window.
  static const _retentionHours = 168.0; // 7 days

  // ── Dose model constants ─────────────────────────────────────────────────

  /// Fatigue credit a secondary (synergist) muscle receives per working set,
  /// relative to the primary mover. Bench press fatigues the triceps and
  /// front delts too — roughly half as much per set as direct work.
  static const double secondaryMuscleCredit = 0.5;

  /// How far session dose can shrink/stretch the base recovery window.
  /// A token single set won't drop below 60% of base; a monster session
  /// won't stretch a single bout past 150%.
  static const double minDoseFactor = 0.6;
  static const double maxDoseFactor = 1.5;

  /// How many previous bouts feed the rolling reference dose.
  static const int doseHistoryWindow = 5;

  /// Fraction of unresolved fatigue that carries into a new bout when a
  /// muscle is trained before it has fully recovered.
  static const double fatigueCarryover = 0.5;

  /// Hard ceiling on a bout's total window, as a multiple of base hours —
  /// keeps back-to-back sessions from compounding into a week of "sore".
  static const double maxStackedFactor = 2;

  /// Steepness of the exponential recovery curve. Higher = faster early
  /// recovery with a longer tail.
  static const double _curveSteepness = 3;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Returns the base recovery hours for a given muscle group.
  static double recoveryHoursFor(String muscleGroup) =>
      (_muscleSizeMap[muscleGroup] ?? MuscleSize.medium).baseRecoveryHours;

  /// Normalised recovery curve: maps elapsed/total time `t ∈ [0, 1]` to a
  /// recovery fraction in [0, 1]. Exponential — fast early repair, slow
  /// tail — normalised so it reaches exactly 1.0 at the deadline.
  /// Physiologically closer to observed DOMS resolution than a straight
  /// line (Damas et al., 2015).
  @visibleForTesting
  static double recoveryCurve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    return (1 - math.exp(-_curveSteepness * t)) /
        (1 - math.exp(-_curveSteepness));
  }

  /// Session dose relative to the user's typical dose for that muscle,
  /// clamped to [minDoseFactor, maxDoseFactor]. Reference 0 (first ever
  /// bout) → factor 1.
  @visibleForTesting
  static double doseFactor(double dose, double referenceDose) {
    if (referenceDose <= 0 || dose <= 0) return 1;
    return (dose / referenceDose).clamp(minDoseFactor, maxDoseFactor);
  }

  /// Folds a muscle's chronological dose history into the recovery window
  /// of its latest bout.
  ///
  /// Per bout: `hours = base × doseFactor` where the reference dose is the
  /// mean of up to [doseHistoryWindow] previous bouts. Training a muscle
  /// that is still recovering carries [fatigueCarryover] of the unresolved
  /// hours into the new window (fatigue stacks instead of resetting),
  /// capped at [maxStackedFactor] × base.
  @visibleForTesting
  static MuscleRecoveryWindow? resolveRecoveryWindow(
    String muscleGroup,
    List<MuscleDoseEvent> history,
  ) {
    if (history.isEmpty) return null;

    final events = [...history]
      ..sort((a, b) => a.trainedAt.compareTo(b.trainedAt));
    final base = recoveryHoursFor(muscleGroup);

    DateTime? fatigueEndsAt;
    var windowHours = base;
    final previousDoses = <double>[];

    for (final event in events) {
      final recentDoses = previousDoses.length > doseHistoryWindow
          ? previousDoses.sublist(previousDoses.length - doseHistoryWindow)
          : previousDoses;
      final reference = recentDoses.isEmpty
          ? 0.0
          : recentDoses.reduce((a, b) => a + b) / recentDoses.length;

      var hours = base * doseFactor(event.dose, reference);

      if (fatigueEndsAt != null && fatigueEndsAt.isAfter(event.trainedAt)) {
        final remaining =
            fatigueEndsAt.difference(event.trainedAt).inMinutes / 60.0;
        hours = math.min(
          hours + fatigueCarryover * remaining,
          maxStackedFactor * base,
        );
      }

      windowHours = hours;
      fatigueEndsAt =
          event.trainedAt.add(Duration(minutes: (hours * 60).round()));
      previousDoses.add(event.dose);
    }

    return MuscleRecoveryWindow(
      lastTrainedAt: events.last.trainedAt,
      recoveryHours: windowHours,
    );
  }

  /// Determines the [MuscleState] for a muscle group given its last workout.
  /// [recoveryHours] defaults to the group's base hours when the caller has
  /// no dose-adjusted window.
  MuscleState getState(
    String muscleGroup,
    DateTime? lastTrainedAt, {
    double? recoveryHours,
  }) {
    if (lastTrainedAt == null) return MuscleState.undertrained;

    final hoursSince =
        DateTime.now().difference(lastTrainedAt).inMinutes / 60.0;
    final recoveryH = recoveryHours ?? recoveryHoursFor(muscleGroup);

    if (hoursSince < recoveryH) return MuscleState.recovering;
    if (hoursSince <= _retentionHours) return MuscleState.recovered;
    return MuscleState.undertrained;
  }

  /// Returns a recovery percentage from 0.0 (just trained) to 1.0 (fully
  /// recovered), following the exponential [recoveryCurve]. Stays at 1.0
  /// during the retention window. Returns null when the muscle has never
  /// been trained or has faded past the retention window.
  double? getRecoveryPercent(
    String muscleGroup,
    DateTime? lastTrainedAt, {
    double? recoveryHours,
  }) {
    if (lastTrainedAt == null) return null;

    final hoursSince =
        DateTime.now().difference(lastTrainedAt).inMinutes / 60.0;
    final recoveryH = recoveryHours ?? recoveryHoursFor(muscleGroup);

    // Past the 7-day retention window → untrained
    if (hoursSince > _retentionHours) return null;

    // Fully recovered and within retention window
    if (hoursSince >= recoveryH) return 1;

    return recoveryCurve(hoursSince / recoveryH).clamp(0.0, 1.0);
  }

  // ── Data layer ──────────────────────────────────────────────────────────

  /// Builds the chronological dose history per muscle group from completed
  /// sessions: each session contributes its completed working sets to the
  /// primary muscle group (×1.0) and to every secondary muscle group
  /// (×[secondaryMuscleCredit]).
  Future<Map<String, List<MuscleDoseEvent>>> _getMuscleDoseHistory() async {
    final sessions = await _sessionDao.getAll();
    final finished = sessions.where((s) => s.finishedAt != null).toList();
    if (finished.isEmpty) return {};

    // Batch: all session exercises, their sets, and the exercises referenced.
    final sessionIds = finished.map((s) => s.localId).toList();
    final allSessionExercises =
        await _sessionDao.getSessionExercisesForSessions(sessionIds);
    if (allSessionExercises.isEmpty) return {};

    final allSets = await _sessionDao.getSetsForSessionExercises(
      allSessionExercises.map((se) => se.localId).toList(),
    );

    final uniqueExerciseIds =
        allSessionExercises.map((se) => se.exerciseId).toSet().toList();
    final exerciseList =
        uniqueExerciseIds.isNotEmpty
            ? await _exerciseDao.findByExerciseIds(uniqueExerciseIds)
            : <Exercise>[];
    final exerciseMap = {for (final e in exerciseList) e.exerciseId: e};

    final sessionFinishedAt = {
      for (final s in finished) s.localId: s.finishedAt!,
    };

    // Completed working sets per session exercise.
    final workingSetsBySeId = <int, int>{};
    for (final set in allSets) {
      if (!set.isCompleted || set.isWarmup) continue;
      workingSetsBySeId[set.sessionExerciseId] =
          (workingSetsBySeId[set.sessionExerciseId] ?? 0) + 1;
    }

    // Dose per (sessionId, muscleGroup).
    final dosePerSessionMuscle = <int, Map<String, double>>{};
    for (final se in allSessionExercises) {
      final exercise = exerciseMap[se.exerciseId];
      if (exercise == null) continue;
      final sets = workingSetsBySeId[se.localId] ?? 0;
      if (sets == 0) continue; // exercise was added but never performed

      final primary = exercise.muscleGroup;
      if (primary == null || primary.isEmpty) continue;

      final doses =
          dosePerSessionMuscle.putIfAbsent(se.sessionId, () => {});
      doses[primary] = (doses[primary] ?? 0) + sets.toDouble();

      // Secondary muscles get partial credit. Raw names ("triceps",
      // "delts") resolve through the same mapping as primaries.
      for (final raw
          in ExerciseMapping.decodeJsonList(exercise.secondaryMuscles)) {
        final group = ExerciseMapping.resolveGymMuscleGroup(
          target: raw,
          bodyPart: null,
          exerciseName: exercise.name,
        );
        if (group == primary || group == 'Other') continue;
        doses[group] = (doses[group] ?? 0) + sets * secondaryMuscleCredit;
      }
    }

    // Flatten to per-muscle chronological event lists.
    final history = <String, List<MuscleDoseEvent>>{};
    dosePerSessionMuscle.forEach((sessionId, doses) {
      final trainedAt = sessionFinishedAt[sessionId];
      if (trainedAt == null) return;
      doses.forEach((group, dose) {
        history.putIfAbsent(group, () => []).add(
              MuscleDoseEvent(trainedAt: trainedAt, dose: dose),
            );
      });
    });
    for (final events in history.values) {
      events.sort((a, b) => a.trainedAt.compareTo(b.trainedAt));
    }
    return history;
  }

  /// Returns recovery state for every canonical muscle group.
  Future<List<MuscleStateInfo>> getAllMuscleStates() async {
    final history = await _getMuscleDoseHistory();

    return _allMuscleGroups.map((group) {
      final window = resolveRecoveryWindow(group, history[group] ?? const []);
      final trainedAt = window?.lastTrainedAt;
      final recoveryH = window?.recoveryHours;
      return MuscleStateInfo(
        muscleGroup: group,
        state: getState(group, trainedAt, recoveryHours: recoveryH),
        lastTrainedAt: trainedAt,
        recoveryPercent:
            getRecoveryPercent(group, trainedAt, recoveryHours: recoveryH),
        recoveryHours: recoveryH,
      );
    }).toList();
  }
}
