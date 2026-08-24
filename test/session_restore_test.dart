import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/workout/workout_log_repository.dart';

/// Session restore (crash / process-kill recovery): the restored session must
/// carry `lastActivityAt` — the newest persisted touch — so the active-session
/// clock can book the dead span (kill → reopen) as paused instead of counting
/// it as workout time.
void main() {
  late AppDatabase db;
  late WorkoutLogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorkoutLogRepository(
      sessionDao: SessionDao(db),
      exerciseDao: ExerciseDao(db),
      scheduleDao: ScheduleDao(db),
      syncService: SyncService(db, null),
    );
  });

  tearDown(() => db.close());

  // Drift persists DateTimes at whole-second precision — build times without
  // sub-second components so round-tripped values compare equal.
  DateTime nowTruncated() {
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }

  Future<int> seedSession(DateTime startedAt, {DateTime? updatedAt}) =>
      db.into(db.sessions).insert(
            SessionsCompanion.insert(
              startedAt: startedAt,
              updatedAt: Value(updatedAt),
            ),
          );

  Future<int> seedSessionExercise(
    int sessionId, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      db.into(db.sessionExercises).insert(
            SessionExercisesCompanion.insert(
              sessionId: sessionId,
              exerciseId: 'ex1',
              orderIndex: 0,
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
            ),
          );

  Future<void> seedSet(
    int seId,
    int index, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              sessionExerciseId: seId,
              setIndex: index,
              weight: const Value(100),
              reps: const Value(5),
              isCompleted: const Value(true),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
            ),
          );

  test('lastActivityAt is the newest touch across session/exercises/sets',
      () async {
    final started = nowTruncated().subtract(const Duration(hours: 3));
    final lastSetTouch = nowTruncated().subtract(const Duration(hours: 1));

    final sessionId = await seedSession(started, updatedAt: started);
    final seId = await seedSessionExercise(
      sessionId,
      createdAt: started.add(const Duration(minutes: 1)),
    );
    await seedSet(
      seId,
      0,
      createdAt: started.add(const Duration(minutes: 10)),
      updatedAt: started.add(const Duration(minutes: 12)),
    );
    await seedSet(seId, 1, updatedAt: lastSetTouch);

    final restored = await repo.getRestorableSession();
    expect(restored, isNotNull);
    expect(restored!.sessionId, sessionId);
    expect(restored.startedAt, started);
    expect(restored.lastActivityAt, lastSetTouch);
  });

  test('lastActivityAt floors at startedAt when rows carry no timestamps',
      () async {
    final started = nowTruncated().subtract(const Duration(hours: 2));
    final sessionId = await seedSession(started);
    final seId = await seedSessionExercise(sessionId);
    await seedSet(seId, 0);

    final restored = await repo.getRestorableSession();
    expect(restored!.sessionId, sessionId);
    expect(restored.lastActivityAt, started);
  });

  test('empty session restores with lastActivityAt = startedAt', () async {
    final started = nowTruncated().subtract(const Duration(minutes: 30));
    await seedSession(started);

    final restored = await repo.getRestorableSession();
    expect(restored, isNotNull);
    expect(restored!.exercises, isEmpty);
    expect(restored.lastActivityAt, started);
  });

  test('sessions older than the restore window are not restorable', () async {
    final started = nowTruncated().subtract(
      WorkoutLogRepository.restoreWindow + const Duration(minutes: 5),
    );
    await seedSession(started);

    expect(await repo.getRestorableSession(), isNull);
  });
}
