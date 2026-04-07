import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/exercise_dao.dart';
import '../../core/database/daos/session_dao.dart';
import '../../shared/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Muscle State Enum
// ─────────────────────────────────────────────────────────────────────────────

/// The three lifecycle phases of a muscle after training.
///
/// ```
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
  large(baseRecoveryHours: 60.0),

  /// Mid-size movers — moderate fibre volume, moderate CNS demand.
  /// Base recovery: **36–48 h** (we use 42 h midpoint).
  medium(baseRecoveryHours: 42.0),

  /// Small / stabiliser muscles — low total volume, fast turnover.
  /// Base recovery: **24–36 h** (we use 30 h midpoint).
  small(baseRecoveryHours: 30.0);

  final double baseRecoveryHours;
  const MuscleSize({required this.baseRecoveryHours});
}

// ─────────────────────────────────────────────────────────────────────────────
// Muscle State Info (public model)
// ─────────────────────────────────────────────────────────────────────────────

class MuscleStateInfo {
  final String muscleGroup;
  final MuscleState state;
  final DateTime? lastTrainedAt;

  /// **Recovery progress**: 0.0 = just trained → 1.0 = fully recovered.
  /// Stays at 1.0 during the "trained & retained" window.
  /// Null when never trained (undertrained).
  final double? recoveryPercent;

  /// Legacy alias — some UI code reads `soreness`.
  /// Soreness is the inverse of recovery: 1.0 = just trained, 0.0 = recovered.
  double? get soreness =>
      recoveryPercent == null ? null : (1.0 - recoveryPercent!).clamp(0.0, 1.0);

  const MuscleStateInfo({
    required this.muscleGroup,
    required this.state,
    this.lastTrainedAt,
    this.recoveryPercent,
  });

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

class MuscleRecoveryService {
  final SessionDao _sessionDao;
  final ExerciseDao _exerciseDao;

  MuscleRecoveryService(this._sessionDao, this._exerciseDao);

  // ── Canonical muscle group list ──────────────────────────────────────────

  static const _allMuscleGroups = [
    'Chest',
    'Lats',
    'Upper Back',
    'Lower Back',
    'Traps',
    'Shoulders',
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
    'Shoulders': MuscleSize.medium, // 3-head deltoid
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
  /// green for this long before fading to untrained (grey).
  static const _retentionHours = 168.0; // 7 days

  // ── Public API ──────────────────────────────────────────────────────────

  /// Returns the base recovery hours for a given muscle group.
  static double recoveryHoursFor(String muscleGroup) =>
      (_muscleSizeMap[muscleGroup] ?? MuscleSize.medium).baseRecoveryHours;

  /// Determines the [MuscleState] for a muscle group given its last workout.
  MuscleState getState(String muscleGroup, DateTime? lastTrainedAt) {
    if (lastTrainedAt == null) return MuscleState.undertrained;

    final hoursSince =
        DateTime.now().difference(lastTrainedAt).inMinutes / 60.0;
    final recoveryH = recoveryHoursFor(muscleGroup);

    if (hoursSince < recoveryH) return MuscleState.recovering;
    if (hoursSince <= _retentionHours) return MuscleState.recovered;
    return MuscleState.undertrained;
  }

  /// Returns a recovery percentage from 0.0 (just trained) to 1.0 (fully
  /// recovered).  Stays at 1.0 during the retention window.
  /// Returns null when the muscle has never been trained or has faded past
  /// the retention window.
  double? getRecoveryPercent(String muscleGroup, DateTime? lastTrainedAt) {
    if (lastTrainedAt == null) return null;

    final hoursSince =
        DateTime.now().difference(lastTrainedAt).inMinutes / 60.0;
    final recoveryH = recoveryHoursFor(muscleGroup);

    // Past the 7-day retention window → untrained
    if (hoursSince > _retentionHours) return null;

    // Fully recovered and within retention window
    if (hoursSince >= recoveryH) return 1.0;

    // Still recovering: linear 0.0 → 1.0 over recoveryH hours
    return (hoursSince / recoveryH).clamp(0.0, 1.0);
  }

  // ── Data layer ──────────────────────────────────────────────────────────

  /// Get last-trained dates per muscle group from completed sessions.
  Future<Map<String, DateTime>> _getLastTrainedDates() async {
    final sessions = await _sessionDao.getAll();
    final finished = sessions.where((s) => s.finishedAt != null).toList();
    if (finished.isEmpty) return {};

    // Batch: get all session exercises in one query
    final sessionIds = finished.map((s) => s.localId).toList();
    final allSessionExercises =
        await _sessionDao.getSessionExercisesForSessions(sessionIds);

    // Batch: get all exercises referenced
    final uniqueExerciseIds =
        allSessionExercises.map((se) => se.exerciseId).toSet().toList();
    final exerciseList = uniqueExerciseIds.isNotEmpty
        ? await _exerciseDao.findByExerciseIds(uniqueExerciseIds)
        : <Exercise>[];
    final exerciseMap = {for (final e in exerciseList) e.exerciseId: e};

    // Map sessionId to finishedAt
    final sessionFinishedAt = {
      for (final s in finished) s.localId: s.finishedAt!
    };

    // Build last-trained dates
    final Map<String, DateTime> lastTrained = {};
    for (final se in allSessionExercises) {
      final exercise = exerciseMap[se.exerciseId];
      if (exercise == null || exercise.muscleGroup == null) continue;

      final group = exercise.muscleGroup!;
      final trainedAt = sessionFinishedAt[se.sessionId];
      if (trainedAt == null) continue;

      if (!lastTrained.containsKey(group) ||
          trainedAt.isAfter(lastTrained[group]!)) {
        lastTrained[group] = trainedAt;
      }
    }

    return lastTrained;
  }

  /// Returns recovery state for every canonical muscle group.
  Future<List<MuscleStateInfo>> getAllMuscleStates() async {
    final lastTrained = await _getLastTrainedDates();

    return _allMuscleGroups.map((group) {
      final trainedAt = lastTrained[group];
      return MuscleStateInfo(
        muscleGroup: group,
        state: getState(group, trainedAt),
        lastTrainedAt: trainedAt,
        recoveryPercent: getRecoveryPercent(group, trainedAt),
      );
    }).toList();
  }
}
