import 'package:drift/drift.dart';

import '../app_database.dart';

part 'session_dao.g.dart';

/// Data access object for workout sessions, session exercises, and sets.
@DriftAccessor(tables: [Sessions, SessionExercises, WorkoutSets])
class SessionDao extends DatabaseAccessor<AppDatabase>
    with _$SessionDaoMixin {
  SessionDao(super.db);

  /// Get all sessions ordered by most recent.
  Future<List<Session>> getAll() =>
      (select(sessions)..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  /// Stream all sessions ordered by most recent.
  Stream<List<Session>> watchAll() =>
      (select(sessions)..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  /// Get a single session by id.
  Future<Session?> getById(int id) =>
      (select(sessions)..where((t) => t.localId.equals(id)))
          .getSingleOrNull();

  /// Create a new session and return its local id.
  Future<int> createSession(SessionsCompanion companion) =>
      into(sessions).insert(companion);

  /// Finish a session with duration and volume.
  Future<void> finishSession(int localId, DateTime finishedAt,
      int durationSecs, double totalVol) =>
      (update(sessions)..where((t) => t.localId.equals(localId))).write(
        SessionsCompanion(
          finishedAt: Value(finishedAt),
          durationSeconds: Value(durationSecs),
          totalVolume: Value(totalVol),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Add an exercise to a session.
  Future<int> addSessionExercise(SessionExercisesCompanion companion) =>
      into(sessionExercises).insert(companion);

  /// Get exercises for a session.
  Future<List<SessionExercise>> getSessionExercises(int sessionId) =>
      (select(sessionExercises)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  /// Add a set to a session exercise.
  Future<int> addSet(WorkoutSetsCompanion companion) =>
      into(workoutSets).insert(companion);

  /// Get sets for a session exercise.
  Future<List<WorkoutSet>> getSets(int sessionExerciseId) =>
      (select(workoutSets)
            ..where((t) => t.sessionExerciseId.equals(sessionExerciseId))
            ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
          .get();

  /// Update a set.
  Future<bool> updateSet(WorkoutSet entity) =>
      update(workoutSets).replace(entity);

  /// Delete a set by local id.
  Future<int> deleteSet(int localId) =>
      (delete(workoutSets)..where((t) => t.localId.equals(localId))).go();

  /// Get the N most recent completed sessions.
  Future<List<Session>> getRecent(int limit) => (select(sessions)
        ..where((t) => t.finishedAt.isNotNull())
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
        ..limit(limit))
      .get();

  /// Stream the N most recent completed sessions.
  Stream<List<Session>> watchRecent(int limit) => (select(sessions)
        ..where((t) => t.finishedAt.isNotNull())
        ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
        ..limit(limit))
      .watch();

  /// Get completed sessions within a date range.
  Future<List<Session>> getInRange(DateTime from, DateTime to) =>
      (select(sessions)
            ..where((t) =>
                t.finishedAt.isNotNull() &
                t.startedAt.isBiggerOrEqualValue(from) &
                t.startedAt.isSmallerOrEqualValue(to))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .get();

  /// Stream completed sessions within a date range.
  Stream<List<Session>> watchInRange(DateTime from, DateTime to) =>
      (select(sessions)
            ..where((t) =>
                t.finishedAt.isNotNull() &
                t.startedAt.isBiggerOrEqualValue(from) &
                t.startedAt.isSmallerOrEqualValue(to))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  /// Get all session exercises for multiple sessions at once.
  Future<List<SessionExercise>> getSessionExercisesForSessions(List<int> sessionIds) =>
      (select(sessionExercises)
            ..where((t) => t.sessionId.isIn(sessionIds))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  /// Get all sets for multiple session exercises at once.
  Future<List<WorkoutSet>> getSetsForSessionExercises(List<int> sessionExerciseIds) =>
      (select(workoutSets)
            ..where((t) => t.sessionExerciseId.isIn(sessionExerciseIds))
            ..orderBy([(t) => OrderingTerm.asc(t.setIndex)]))
          .get();

  /// Check if a completed session exists on a specific date.
  Future<bool> hasSessionOnDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final results = await getInRange(start, end);
    return results.isNotEmpty;
  }

  /// Count completed sessions for a specific schedule.
  Future<int> countBySchedule(int scheduleId) async {
    final countExp = sessions.localId.count();
    final query = selectOnly(sessions)
      ..addColumns([countExp])
      ..where(
        sessions.scheduleId.equals(scheduleId) &
        sessions.finishedAt.isNotNull(),
      );
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Get the most recent completed session for a specific schedule.
  Future<Session?> getLastForSchedule(int scheduleId) =>
      (select(sessions)
            ..where((t) =>
                t.scheduleId.equals(scheduleId) &
                t.finishedAt.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(1))
          .getSingleOrNull();
}
