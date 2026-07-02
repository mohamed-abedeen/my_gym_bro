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

/// A patch value for partial updates. Distinguishes "field not provided"
/// (`Patch.unchanged()`) from "field explicitly set to null" (`Patch.set(null)`).
/// Mirrors Drift's `Value<T>` without leaking it into the UI layer.
class Patch<T> {
  const Patch.unchanged()
      : present = false,
        _value = null;
  const Patch.set(T value)
      : present = true,
        _value = value;
  final bool present;
  final T? _value;
  T? get value => _value;
}

/// Parameters needed to create a new workout session.
class CreateSessionParams {
  const CreateSessionParams({required this.startedAt, this.scheduleId});
  final DateTime startedAt;
  final int? scheduleId;
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

/// Parameters needed to update fields on an existing set. Each field uses
/// [Patch] so callers can distinguish "leave alone" from "clear to null".
class UpdateSetParams {
  const UpdateSetParams({
    required this.sessionExerciseId,
    required this.setLocalId,
    this.weight = const Patch.unchanged(),
    this.reps = const Patch.unchanged(),
    this.durationSeconds = const Patch.unchanged(),
    this.distance = const Patch.unchanged(),
    this.speed = const Patch.unchanged(),
    this.incline = const Patch.unchanged(),
  });
  final int sessionExerciseId;
  final int setLocalId;
  final Patch<double?> weight;
  final Patch<int?> reps;
  final Patch<int?> durationSeconds;
  final Patch<double?> distance;
  final Patch<double?> speed;
  final Patch<double?> incline;
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

/// A set reloaded from Drift when restoring an in-progress session.
class RestoredSetInfo {
  const RestoredSetInfo({
    required this.localId,
    required this.setIndex,
    this.weight,
    this.reps,
    this.isWarmup = false,
    this.isDropset = false,
    this.isFailure = false,
    this.isCompleted = false,
    this.durationSeconds,
    this.distance,
    this.speed,
    this.incline,
  });
  final int localId;
  final int setIndex;
  final double? weight;
  final int? reps;
  final bool isWarmup;
  final bool isDropset;
  final bool isFailure;
  final bool isCompleted;
  final int? durationSeconds;
  final double? distance;
  final double? speed;
  final double? incline;
}

/// A session exercise reloaded from Drift when restoring a session.
class RestoredExerciseInfo {
  const RestoredExerciseInfo({
    required this.sessionExerciseId,
    required this.exerciseId,
    required this.name,
    this.gifUrl,
    this.muscleGroup,
    this.sets = const [],
  });
  final int sessionExerciseId;
  final String exerciseId;
  final String name;
  final String? gifUrl;
  final String? muscleGroup;
  final List<RestoredSetInfo> sets;
}

/// An in-progress session reloaded from Drift after a process kill.
class RestoredSessionInfo {
  const RestoredSessionInfo({
    required this.sessionId,
    required this.startedAt,
    this.exercises = const [],
  });
  final int sessionId;
  final DateTime startedAt;
  final List<RestoredExerciseInfo> exercises;
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
      scheduleId: params.scheduleId == null
          ? const Value.absent()
          : Value(params.scheduleId),
    ));
  }

  /// Look up a schedule day to find its parent schedule ID.
  Future<int?> getScheduleIdForDay(int scheduleDayId) async {
    final day = await _scheduleDao.getDayById(scheduleDayId);
    return day?.scheduleId;
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

  /// Delete an entire session and cascade to its exercises and sets.
  Future<void> deleteSession(int sessionId) {
    return _sessionDao.deleteSession(sessionId);
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

  /// Update strength/cardio fields on a set. Only fields whose [Patch] is
  /// `present` are written; absent patches leave the column unchanged.
  Future<void> updateSet(UpdateSetParams params) async {
    final sets = await _sessionDao.getSets(params.sessionExerciseId);
    final dbSet = sets.firstWhere((s) => s.localId == params.setLocalId);
    await _sessionDao.updateSet(dbSet.copyWith(
      weight: params.weight.present
          ? Value(params.weight.value)
          : const Value.absent(),
      reps: params.reps.present
          ? Value(params.reps.value)
          : const Value.absent(),
      durationSeconds: params.durationSeconds.present
          ? Value(params.durationSeconds.value)
          : const Value.absent(),
      distance: params.distance.present
          ? Value(params.distance.value)
          : const Value.absent(),
      speed: params.speed.present
          ? Value(params.speed.value)
          : const Value.absent(),
      incline: params.incline.present
          ? Value(params.incline.value)
          : const Value.absent(),
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

  /// Mark a set as completed (or un-completed) and persist immediately so
  /// the state survives a process kill.
  Future<void> setCompletion({
    required int sessionExerciseId,
    required int setLocalId,
    required bool isCompleted,
  }) async {
    final sets = await _sessionDao.getSets(sessionExerciseId);
    final dbSet = sets.firstWhere((s) => s.localId == setLocalId);
    await _sessionDao.updateSet(dbSet.copyWith(isCompleted: isCompleted));
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

  // ── Session restore (crash / process-kill recovery) ────────────────────

  /// How long an unfinished session stays restorable before being treated
  /// as abandoned by [reconcileAbandonedSessions].
  static const Duration restoreWindow = Duration(hours: 12);

  /// The most recent unfinished session started within [restoreWindow],
  /// with its exercises and sets, or null when there is nothing to restore.
  Future<RestoredSessionInfo?> getRestorableSession() async {
    final sessions = await _sessionDao.getAll();
    final cutoff = DateTime.now().subtract(restoreWindow);
    final candidates = sessions
        .where((s) =>
            s.finishedAt == null &&
            s.deletedAt == null &&
            s.startedAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (candidates.isEmpty) return null;
    final session = candidates.first;

    final sessionExercises = await _sessionDao
        .getSessionExercisesForSessions([session.localId])
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (sessionExercises.isEmpty) {
      return RestoredSessionInfo(
        sessionId: session.localId,
        startedAt: session.startedAt,
      );
    }

    final sets = await _sessionDao.getSetsForSessionExercises(
      sessionExercises.map((se) => se.localId).toList(),
    );
    final setsBySeId = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      setsBySeId.putIfAbsent(s.sessionExerciseId, () => []).add(s);
    }

    final exerciseRows = await _exerciseDao.findByExerciseIds(
      sessionExercises.map((se) => se.exerciseId).toSet().toList(),
    );
    final exerciseMap = {for (final e in exerciseRows) e.exerciseId: e};

    final exercises = <RestoredExerciseInfo>[];
    for (final se in sessionExercises) {
      final exercise = exerciseMap[se.exerciseId];
      final seSets = (setsBySeId[se.localId] ?? [])
        ..sort((a, b) => a.setIndex.compareTo(b.setIndex));
      exercises.add(RestoredExerciseInfo(
        sessionExerciseId: se.localId,
        exerciseId: se.exerciseId,
        // Exercise metadata can be missing offline — restore with a
        // readable placeholder rather than dropping the logged work.
        name: exercise?.name ?? 'Exercise',
        gifUrl: exercise?.gifUrl,
        muscleGroup: exercise?.muscleGroup,
        sets: [
          for (final s in seSets)
            RestoredSetInfo(
              localId: s.localId,
              setIndex: s.setIndex,
              weight: s.weight,
              reps: s.reps,
              isWarmup: s.isWarmup,
              isDropset: s.isDropset,
              isFailure: s.isFailure,
              isCompleted: s.isCompleted,
              durationSeconds: s.durationSeconds,
              distance: s.distance,
              speed: s.speed,
              incline: s.incline,
            ),
        ],
      ));
    }

    return RestoredSessionInfo(
      sessionId: session.localId,
      startedAt: session.startedAt,
      exercises: exercises,
    );
  }

  /// Reconcile unfinished sessions older than [restoreWindow]: sessions
  /// with at least one completed set are auto-finished (so a workout the
  /// OS killed mid-session still lands in history instead of silently
  /// vanishing); empty ones are deleted.
  Future<void> reconcileAbandonedSessions() async {
    final sessions = await _sessionDao.getAll();
    final cutoff = DateTime.now().subtract(restoreWindow);
    final abandoned = sessions
        .where((s) =>
            s.finishedAt == null &&
            s.deletedAt == null &&
            !s.startedAt.isAfter(cutoff))
        .toList();
    if (abandoned.isEmpty) return;

    final sessionExercises = await _sessionDao.getSessionExercisesForSessions(
      abandoned.map((s) => s.localId).toList(),
    );
    final sets = sessionExercises.isEmpty
        ? <WorkoutSet>[]
        : await _sessionDao.getSetsForSessionExercises(
            sessionExercises.map((se) => se.localId).toList(),
          );

    final sessionIdBySeId = {
      for (final se in sessionExercises) se.localId: se.sessionId,
    };
    final setsBySessionId = <int, List<WorkoutSet>>{};
    for (final s in sets) {
      final sessionId = sessionIdBySeId[s.sessionExerciseId];
      if (sessionId == null) continue;
      setsBySessionId.putIfAbsent(sessionId, () => []).add(s);
    }

    for (final session in abandoned) {
      final sessionSets = setsBySessionId[session.localId] ?? const [];
      final completed =
          sessionSets.where((s) => s.isCompleted).toList(growable: false);

      if (completed.isEmpty) {
        await deleteSession(session.localId);
        continue;
      }

      double volume = 0;
      var lastActivity = session.startedAt;
      for (final s in completed) {
        if (s.weight != null && s.reps != null) {
          volume += s.weight! * s.reps!;
        }
        final touched = s.updatedAt ?? s.createdAt;
        if (touched != null && touched.isAfter(lastActivity)) {
          lastActivity = touched;
        }
      }

      // Duration from first to last recorded activity, kept plausible:
      // at least a minute, at most four hours.
      final duration = lastActivity
          .difference(session.startedAt)
          .inSeconds
          .clamp(60, 4 * 3600);

      await finishSession(FinishSessionParams(
        sessionId: session.localId,
        finishedAt: session.startedAt.add(Duration(seconds: duration)),
        durationSeconds: duration,
        totalVolume: volume,
      ));
    }
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
