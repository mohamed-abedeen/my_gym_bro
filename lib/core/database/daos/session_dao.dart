import 'package:drift/drift.dart';

import 'package:my_gym_bro/core/database/app_database.dart';

part 'session_dao.g.dart';

class ExercisePersonalRecords {
  const ExercisePersonalRecords({
    this.maxWeight,
    this.best1rm,
    this.bestSetVolume,
    this.bestSessionVolume,
  });
  final double? maxWeight;
  final double? best1rm;
  final double? bestSetVolume;
  final double? bestSessionVolume;
}

class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    required this.session,
    required this.sets,
    this.scheduleName,
  });
  final Session session;
  final List<WorkoutSet> sets;
  final String? scheduleName;
}

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

  /// Delete an entire session and all its exercises and sets.
  Future<void> deleteSession(int sessionId) async {
    // 1. Find all session exercises for this session.
    final exercises = await getSessionExercises(sessionId);
    // 2. Delete all sets belonging to those exercises.
    for (final ex in exercises) {
      await (delete(workoutSets)
            ..where((t) => t.sessionExerciseId.equals(ex.localId)))
          .go();
    }
    // 3. Delete all session exercises.
    await (delete(sessionExercises)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
    // 4. Delete the session itself.
    await (delete(sessions)..where((t) => t.localId.equals(sessionId))).go();
  }

  /// Persist a new display order for a session exercise.
  Future<void> updateSessionExerciseOrder(
          int sessionExerciseId, int orderIndex) =>
      (update(sessionExercises)
            ..where((t) => t.localId.equals(sessionExerciseId)))
          .write(SessionExercisesCompanion(orderIndex: Value(orderIndex)));

  /// Delete a session exercise and all its sets.
  Future<void> deleteSessionExercise(int sessionExerciseId) async {
    await (delete(workoutSets)
          ..where((t) => t.sessionExerciseId.equals(sessionExerciseId)))
        .go();
    await (delete(sessionExercises)
          ..where((t) => t.localId.equals(sessionExerciseId)))
        .go();
  }

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

  /// Distinct local calendar days (midnight) on which at least one completed
  /// session was started, newest first. Used by the streak calculation so it
  /// can count consecutive days in Dart from a single SQL round-trip instead
  /// of issuing one query per day.
  Future<List<DateTime>> getDistinctSessionDatesDescending({
    int limit = 365,
  }) async {
    // Drift stores DateTime as unix-epoch seconds by default. `date(...,
    // 'unixepoch', 'localtime')` groups by the user's local calendar day.
    final rows = await customSelect(
      "SELECT DISTINCT date(started_at, 'unixepoch', 'localtime') AS d "
      'FROM sessions '
      'WHERE finished_at IS NOT NULL '
      'ORDER BY d DESC '
      'LIMIT ?',
      variables: [Variable<int>(limit)],
      readsFrom: {sessions},
    ).get();

    return [
      for (final row in rows) DateTime.parse(row.read<String>('d')),
    ];
  }

  /// Per-session total volume for a given exercise, oldest→newest (up to [limit]).
  Future<List<double>> getVolumeHistoryForExercise(
    String exerciseId, {
    int limit = 10,
  }) async {
    final rows = await customSelect(
      'SELECT SUM(ws.weight * ws.reps) AS volume '
      'FROM session_exercises se '
      'JOIN workout_sets ws ON ws.session_exercise_id = se.local_id '
      'WHERE se.exercise_id = ? '
      '  AND ws.weight IS NOT NULL AND ws.reps IS NOT NULL '
      'GROUP BY se.local_id '
      'ORDER BY se.created_at DESC '
      'LIMIT ?',
      variables: [Variable<String>(exerciseId), Variable<int>(limit)],
      readsFrom: {sessionExercises, workoutSets},
    ).get();

    // Reverse so chart shows oldest on the left.
    return rows.reversed
        .map((r) => r.read<double?>('volume') ?? 0.0)
        .toList();
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

  /// Per-session volume with dates for a given exercise, oldest→newest.
  Future<List<({DateTime date, double volume})>> getVolumeHistoryWithDates(
    String exerciseId, {
    DateTime? from,
    int limit = 20,
  }) async {
    final fromClause = from != null ? 'AND s.started_at >= ?' : '';
    final variables = <Variable>[
      Variable<String>(exerciseId),
      if (from != null) Variable<int>(from.millisecondsSinceEpoch ~/ 1000),
      Variable<int>(limit),
    ];

    final rows = await customSelect(
      'SELECT s.started_at, SUM(ws.weight * ws.reps) AS volume '
      'FROM session_exercises se '
      'JOIN workout_sets ws ON ws.session_exercise_id = se.local_id '
      'JOIN sessions s ON s.local_id = se.session_id '
      'WHERE se.exercise_id = ? '
      '  AND ws.weight IS NOT NULL AND ws.reps IS NOT NULL '
      '  $fromClause '
      'GROUP BY se.local_id '
      'ORDER BY s.started_at DESC '
      'LIMIT ?',
      variables: variables,
      readsFrom: {sessionExercises, workoutSets, sessions},
    ).get();

    return rows.reversed
        .map((r) => (
              date: DateTime.fromMillisecondsSinceEpoch(
                  r.read<int>('started_at') * 1000),
              volume: r.read<double?>('volume') ?? 0.0,
            ))
        .toList();
  }

  /// Personal records for a given exercise.
  Future<ExercisePersonalRecords> getPersonalRecords(
      String exerciseId) async {
    final setRow = await customSelect(
      'SELECT '
      '  MAX(ws.weight) AS max_weight, '
      '  MAX(ws.weight * (1.0 + CAST(ws.reps AS REAL) / 30.0)) AS best_1rm, '
      '  MAX(ws.weight * ws.reps) AS best_set_volume '
      'FROM session_exercises se '
      'JOIN workout_sets ws ON ws.session_exercise_id = se.local_id '
      'WHERE se.exercise_id = ? '
      '  AND ws.weight IS NOT NULL AND ws.reps IS NOT NULL',
      variables: [Variable<String>(exerciseId)],
      readsFrom: {sessionExercises, workoutSets},
    ).getSingleOrNull();

    final volRow = await customSelect(
      'SELECT MAX(s.total_volume) AS best_session_volume '
      'FROM sessions s '
      'JOIN session_exercises se ON se.session_id = s.local_id '
      'WHERE se.exercise_id = ? AND s.total_volume IS NOT NULL',
      variables: [Variable<String>(exerciseId)],
      readsFrom: {sessions, sessionExercises},
    ).getSingleOrNull();

    return ExercisePersonalRecords(
      maxWeight: setRow?.read<double?>('max_weight'),
      best1rm: setRow?.read<double?>('best_1rm'),
      bestSetVolume: setRow?.read<double?>('best_set_volume'),
      bestSessionVolume: volRow?.read<double?>('best_session_volume'),
    );
  }

  /// Sets from the most recent **completed** session for a given exercise.
  ///
  /// Returns an empty list when the exercise has never been logged before.
  /// Used to auto-fill weights/reps at the start of a new session.
  Future<List<WorkoutSet>> getLastLoggedSets(String exerciseId) async {
    // 1. Find the most recent session_exercise row for this exercise
    //    that belongs to a finished session.
    final seRow = await customSelect(
      'SELECT se.local_id '
      'FROM session_exercises se '
      'JOIN sessions s ON s.local_id = se.session_id '
      'WHERE se.exercise_id = ? AND s.finished_at IS NOT NULL '
      'ORDER BY s.started_at DESC '
      'LIMIT 1',
      variables: [Variable<String>(exerciseId)],
      readsFrom: {sessionExercises, sessions},
    ).getSingleOrNull();

    if (seRow == null) return [];

    final seId = seRow.read<int>('local_id');
    return getSets(seId);
  }

  /// Completed sessions containing this exercise with their sets, newest first.
  Future<List<ExerciseHistoryEntry>> getSessionsForExercise(
      String exerciseId) async {
    final seList = await (select(sessionExercises)
          ..where((t) => t.exerciseId.equals(exerciseId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    if (seList.isEmpty) return [];

    final sessionIds = seList.map((se) => se.sessionId).toSet().toList();
    final sessionList = await (select(sessions)
          ..where(
              (t) => t.localId.isIn(sessionIds) & t.finishedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
    if (sessionList.isEmpty) return [];

    final seIds = seList.map((se) => se.localId).toList();
    final allSets = await getSetsForSessionExercises(seIds);

    final setsBySEId = <int, List<WorkoutSet>>{};
    for (final s in allSets) {
      setsBySEId.putIfAbsent(s.sessionExerciseId, () => []).add(s);
    }
    final seBySessionId = <int, SessionExercise>{};
    for (final se in seList) {
      seBySessionId[se.sessionId] = se;
    }

    // Batch-fetch schedule names
    final scheduleIds = sessionList
        .where((s) => s.scheduleId != null)
        .map((s) => s.scheduleId!)
        .toSet()
        .toList();
    final scheduleNames = <int, String>{};
    if (scheduleIds.isNotEmpty) {
      final schRows = await (attachedDatabase.select(attachedDatabase.schedules)
            ..where((t) => t.localId.isIn(scheduleIds)))
          .get();
      for (final sch in schRows) {
        scheduleNames[sch.localId] = sch.name;
      }
    }

    return sessionList.map((session) {
      final se = seBySessionId[session.localId];
      final sets =
          se != null ? (setsBySEId[se.localId] ?? []) : <WorkoutSet>[];
      return ExerciseHistoryEntry(
        session: session,
        sets: sets,
        scheduleName:
            session.scheduleId != null ? scheduleNames[session.scheduleId] : null,
      );
    }).toList();
  }
}
