import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';

// ── Data-transfer objects ──────────────────────────────────────────────────
// These lightweight classes decouple the UI layer from Drift's generated
// types (Value, Companion, etc.), ensuring the notifier never constructs
// data-layer objects directly.

/// Parameters needed to create a new workout session.
class CreateSessionParams {
  const CreateSessionParams({required this.startedAt});
  final DateTime startedAt;
}

/// Parameters needed to add an exercise to an active session.
class AddSessionExerciseParams {
  const AddSessionExerciseParams({
    required this.sessionId,
    required this.exerciseId,
    required this.orderIndex,
  });
  final int sessionId;
  final String exerciseId;
  final int orderIndex;
}

/// Parameters needed to add a set to a session exercise.
class AddSetParams {
  const AddSetParams({
    required this.sessionExerciseId,
    required this.setIndex,
    this.weight,
    this.reps,
    this.durationSeconds,
    this.distance,
    this.speed,
    this.incline,
  });
  final int sessionExerciseId;
  final int setIndex;
  final double? weight;
  final int? reps;
  final int? durationSeconds;
  final double? distance;
  final double? speed;
  final double? incline;
}

/// Parameters needed to update fields on an existing set.
class UpdateSetParams {
  const UpdateSetParams({
    required this.sessionExerciseId,
    required this.setLocalId,
    this.weight,
    this.reps,
    this.durationSeconds,
    this.distance,
    this.speed,
    this.incline,
  });
  final int sessionExerciseId;
  final int setLocalId;
  final double? weight;
  final int? reps;
  final int? durationSeconds;
  final double? distance;
  final double? speed;
  final double? incline;
}

/// Parameters for updating the set type flags.
class UpdateSetTypeParams {
  const UpdateSetTypeParams({
    required this.sessionExerciseId,
    required this.setLocalId,
    required this.isWarmup,
    required this.isDropset,
    required this.isFailure,
  });
  final int sessionExerciseId;
  final int setLocalId;
  final bool isWarmup;
  final bool isDropset;
  final bool isFailure;
}

/// Parameters needed to finish a workout session.
class FinishSessionParams {
  const FinishSessionParams({
    required this.sessionId,
    required this.finishedAt,
    required this.durationSeconds,
    required this.totalVolume,
  });
  final int sessionId;
  final DateTime finishedAt;
  final int durationSeconds;
  final double totalVolume;
}

/// Lightweight exercise info returned to the notifier.
class ExerciseInfo {
  const ExerciseInfo({
    required this.exerciseId,
    required this.name,
    this.gifUrl,
    this.muscleGroup,
  });
  final String exerciseId;
  final String name;
  final String? gifUrl;
  final String? muscleGroup;
}

/// Lightweight scheduled-exercise info returned to the notifier.
class ScheduledExerciseInfo {
  const ScheduledExerciseInfo({
    required this.exerciseId,
    required this.targetSets,
    required this.targetReps,
    required this.orderIndex,
  });
  final String exerciseId;
  final int targetSets;
  final int targetReps;
  final int orderIndex;
}

/// Lightweight last-logged set data returned to the notifier.
class LastLoggedSetInfo {
  const LastLoggedSetInfo({
    this.weight,
    this.reps,
    this.durationSeconds,
    this.distance,
    this.speed,
    this.incline,
  });
  final double? weight;
  final int? reps;
  final int? durationSeconds;
  final double? distance;
  final double? speed;
  final double? incline;
}

// ── Repository ─────────────────────────────────────────────────────────────

/// Abstracts all database and sync operations required by the active session notifier.
///
/// This keeps Drift types (`Value`, `Companion`, `WorkoutSet`, etc.) and raw
/// SQL entirely isolated in the Data layer — the notifier only uses plain Dart
/// DTOs defined above.
class WorkoutLogRepository {
  WorkoutLogRepository({
    required SessionDao sessionDao,
    required ExerciseDao exerciseDao,
    required ScheduleDao scheduleDao,
    required SyncService syncService,
  })  : _sessionDao = sessionDao,
        _exerciseDao = exerciseDao,
        _scheduleDao = scheduleDao,
        _syncService = syncService;

  final SessionDao _sessionDao;
  final ExerciseDao _exerciseDao;
  final ScheduleDao _scheduleDao;
  final SyncService _syncService;

  // ── Session lifecycle ───────────────────────────────────────────────────

  /// Create a new workout session and return its local ID.
  Future<int> createSession(CreateSessionParams params) {
    return _sessionDao.createSession(SessionsCompanion(
      startedAt: Value(params.startedAt),
      createdAt: Value(params.startedAt),
    ));
  }

  /// Finish a session, persist summary data, and enqueue for sync.
  Future<void> finishSession(FinishSessionParams params) async {
    await _sessionDao.finishSession(
      params.sessionId,
      params.finishedAt,
      params.durationSeconds,
      params.totalVolume,
    );

    // Queue for sync — sync_service reads payload['remote_id'] to target the
    // row on Supabase; without it every update is silently dropped.
    final session = await _sessionDao.getById(params.sessionId);
    final remoteId = session?.remoteId;
    if (remoteId != null) {
      try {
        await _syncService.enqueue(
          table: 'sessions',
          rowId: params.sessionId,
          operation: 'update',
          payload: {
            'remote_id': remoteId,
            'finished_at': params.finishedAt.toIso8601String(),
            'duration_seconds': params.durationSeconds,
            'total_volume': params.totalVolume,
          },
        );
      } on Exception catch (e) {
        CrashReporter.recordError(e, reason: 'Session sync failed');
      }
    }
  }

  // ── Session exercises ───────────────────────────────────────────────────

  /// Add an exercise to a session and return the session-exercise local ID.
  Future<int> addSessionExercise(AddSessionExerciseParams params) {
    return _sessionDao.addSessionExercise(SessionExercisesCompanion(
      sessionId: Value(params.sessionId),
      exerciseId: Value(params.exerciseId),
      orderIndex: Value(params.orderIndex),
      createdAt: Value(DateTime.now()),
    ));
  }

  /// Remove a session exercise and all its sets.
  Future<void> deleteSessionExercise(int sessionExerciseId) {
    return _sessionDao.deleteSessionExercise(sessionExerciseId);
  }

  // ── Sets ────────────────────────────────────────────────────────────────

  /// Add a workout set and return its local ID.
  Future<int> addSet(AddSetParams params) {
    return _sessionDao.addSet(WorkoutSetsCompanion(
      sessionExerciseId: Value(params.sessionExerciseId),
      setIndex: Value(params.setIndex),
      weight: Value(params.weight),
      reps: Value(params.reps),
      durationSeconds: Value(params.durationSeconds),
      distance: Value(params.distance),
      speed: Value(params.speed),
      incline: Value(params.incline),
      createdAt: Value(DateTime.now()),
    ));
  }

  /// Update strength/cardio fields on a set.
  Future<void> updateSet(UpdateSetParams params) async {
    final sets = await _sessionDao.getSets(params.sessionExerciseId);
    final dbSet = sets.firstWhere((s) => s.localId == params.setLocalId);
    await _sessionDao.updateSet(dbSet.copyWith(
      weight: Value(params.weight ?? dbSet.weight),
      reps: Value(params.reps ?? dbSet.reps),
      durationSeconds:
          Value(params.durationSeconds ?? dbSet.durationSeconds),
      distance: Value(params.distance ?? dbSet.distance),
      speed: Value(params.speed ?? dbSet.speed),
      incline: Value(params.incline ?? dbSet.incline),
    ));
  }

  /// Update the type flags (warm-up / drop-set / failure) on a set.
  Future<void> updateSetType(UpdateSetTypeParams params) async {
    final sets = await _sessionDao.getSets(params.sessionExerciseId);
    final dbSet = sets.firstWhere((s) => s.localId == params.setLocalId);
    await _sessionDao.updateSet(dbSet.copyWith(
      isWarmup: params.isWarmup,
      isDropset: params.isDropset,
      isFailure: params.isFailure,
    ));
  }

  /// Delete a single set.
  Future<void> deleteSet(int setLocalId) {
    return _sessionDao.deleteSet(setLocalId);
  }

  // ── Exercise lookups ────────────────────────────────────────────────────

  /// Look up an exercise by its ID and return a lightweight DTO.
  Future<ExerciseInfo?> findExercise(String exerciseId) async {
    final exercise = await _exerciseDao.findByExerciseId(exerciseId);
    if (exercise == null) return null;
    return ExerciseInfo(
      exerciseId: exercise.exerciseId,
      name: exercise.name,
      gifUrl: exercise.gifUrl,
      muscleGroup: exercise.muscleGroup,
    );
  }

  /// Batch-fetch exercises by their IDs.
  Future<Map<String, ExerciseInfo>> findExercisesByIds(
      List<String> exerciseIds) async {
    final exercises = await _exerciseDao.findByExerciseIds(exerciseIds);
    return {
      for (final e in exercises)
        e.exerciseId: ExerciseInfo(
          exerciseId: e.exerciseId,
          name: e.name,
          gifUrl: e.gifUrl,
          muscleGroup: e.muscleGroup,
        ),
    };
  }

  /// Increment an exercise's usage counter (fire-and-forget).
  Future<void> incrementExerciseUsage(String exerciseId) {
    return _exerciseDao.incrementUsageCount(exerciseId);
  }

  // ── Schedule exercises ──────────────────────────────────────────────────

  /// Fetch scheduled exercises for a training day, sorted by orderIndex.
  Future<List<ScheduledExerciseInfo>> getScheduledExercises(
      int scheduleDayId) async {
    final exercises = await _scheduleDao.getExercises(scheduleDayId);
    exercises.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return exercises
        .map((e) => ScheduledExerciseInfo(
              exerciseId: e.exerciseId,
              targetSets: e.targetSets,
              targetReps: e.targetReps,
              orderIndex: e.orderIndex,
            ))
        .toList();
  }

  // ── History (auto-fill) ─────────────────────────────────────────────────

  /// Fetch the user's last logged sets for an exercise, mapped to
  /// lightweight DTOs. Returns an empty list if no history exists.
  Future<List<LastLoggedSetInfo>> getLastLoggedSets(String exerciseId) async {
    final sets = await _sessionDao.getLastLoggedSets(exerciseId);
    return sets
        .map((s) => LastLoggedSetInfo(
              weight: s.weight,
              reps: s.reps,
              durationSeconds: s.durationSeconds,
              distance: s.distance,
              speed: s.speed,
              incline: s.incline,
            ))
        .toList();
  }
}
