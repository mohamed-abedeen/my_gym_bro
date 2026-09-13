import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/database/daos/session_dao.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';
import 'package:my_gym_bro/features/workout/workout_log_repository.dart';

/// "Save changes to this day?" when finishing a plan-day session: the session
/// remembers its day (also across a process-kill restore), change detection
/// and planned targets are pure rules, and writing the session's list back
/// keeps the targets of exercises the day already had.
void main() {
  group('scheduleDayExercisesChanged', () {
    test('the same list in the same order is unchanged', () {
      expect(scheduleDayExercisesChanged(['a', 'b'], ['a', 'b']), isFalse);
    });

    test('added, removed, replaced and reordered all count', () {
      expect(scheduleDayExercisesChanged(['a', 'b'], ['a', 'b', 'c']), isTrue);
      expect(scheduleDayExercisesChanged(['a', 'b'], ['a']), isTrue);
      expect(scheduleDayExercisesChanged(['a', 'b'], ['a', 'x']), isTrue);
      expect(scheduleDayExercisesChanged(['a', 'b'], ['b', 'a']), isTrue);
    });

    test('an emptied session never counts (it must not wipe the day)', () {
      expect(scheduleDayExercisesChanged(['a', 'b'], []), isFalse);
    });

    test('filling an empty day counts', () {
      expect(scheduleDayExercisesChanged([], ['a']), isTrue);
    });
  });

  group('plannedTargetsFor', () {
    ActiveExercise exercise(List<ActiveSet> sets) => ActiveExercise(
          sessionExerciseId: 1,
          exerciseId: 'ex',
          name: 'Ex',
          sets: sets,
        );

    test('counts working sets and takes the first working set reps', () {
      final ex = exercise(const [
        ActiveSet(localId: 1, setIndex: 0, reps: 15, isWarmup: true),
        ActiveSet(localId: 2, setIndex: 1, reps: 8),
        ActiveSet(localId: 3, setIndex: 2, reps: 6),
      ]);
      expect(plannedTargetsFor(ex), (sets: 2, reps: 8));
    });

    test('falls back to the 3 x 10 schedule defaults', () {
      expect(plannedTargetsFor(exercise(const [])), (sets: 3, reps: 10));
      expect(
        plannedTargetsFor(exercise(const [
          ActiveSet(localId: 1, setIndex: 0, reps: 12, isWarmup: true),
        ])),
        (sets: 3, reps: 10),
      );
      expect(
        plannedTargetsFor(exercise(const [ActiveSet(localId: 1, setIndex: 0)])),
        (sets: 1, reps: 10),
      );
    });
  });

  group('WorkoutLogRepository', () {
    late AppDatabase db;
    late ScheduleDao scheduleDao;
    late WorkoutLogRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      scheduleDao = ScheduleDao(db);
      repo = WorkoutLogRepository(
        sessionDao: SessionDao(db),
        exerciseDao: ExerciseDao(db),
        scheduleDao: scheduleDao,
        syncService: SyncService(db, null),
      );
    });

    tearDown(() => db.close());

    Future<int> seedSchedule() => scheduleDao.createSchedule(
          const SchedulesCompanion(name: Value('PPL')),
        );

    Future<int> seedDay(int scheduleId, {int index = 0, String? label}) =>
        scheduleDao.addDay(
          ScheduleDaysCompanion(
            scheduleId: Value(scheduleId),
            dayIndex: Value(index),
            label: Value(label),
          ),
        );

    Future<int> seedScheduled(
      int dayId,
      String exerciseId,
      int order, {
      int sets = 3,
      int reps = 10,
      int? durationSeconds,
      double? distance,
    }) =>
        scheduleDao.addExercise(
          ScheduledExercisesCompanion(
            scheduleDayId: Value(dayId),
            exerciseId: Value(exerciseId),
            orderIndex: Value(order),
            targetSets: Value(sets),
            targetReps: Value(reps),
            targetDurationSeconds: Value(durationSeconds),
            targetDistance: Value(distance),
          ),
        );

    ScheduledExerciseInfo info(
      String exerciseId,
      int order, {
      int sets = 3,
      int reps = 10,
    }) =>
        ScheduledExerciseInfo(
          exerciseId: exerciseId,
          targetSets: sets,
          targetReps: reps,
          orderIndex: order,
        );

    test('createSession stores the plan day and restore returns it', () async {
      final scheduleId = await seedSchedule();
      final dayId = await seedDay(scheduleId, label: 'Push');

      final sessionId = await repo.createSession(
        CreateSessionParams(
          startedAt: DateTime.now(),
          scheduleId: scheduleId,
          scheduleDayId: dayId,
        ),
      );

      final row = await (db.select(db.sessions)
            ..where((t) => t.localId.equals(sessionId)))
          .getSingle();
      expect(row.scheduleId, scheduleId);
      expect(row.scheduleDayId, dayId);

      final restored = await repo.getRestorableSession();
      expect(restored?.sessionId, sessionId);
      expect(restored?.scheduleDayId, dayId);
    });

    test('a free session restores with no plan day', () async {
      await repo.createSession(CreateSessionParams(startedAt: DateTime.now()));

      final restored = await repo.getRestorableSession();
      expect(restored, isNotNull);
      expect(restored!.scheduleDayId, isNull);
    });

    test(
        'replaceScheduledExercises writes the session order, keeps the '
        'targets of kept exercises and plans new ones from the session',
        () async {
      final dayId = await seedDay(await seedSchedule());
      await seedScheduled(dayId, 'bench', 0, sets: 5, reps: 5);
      await seedScheduled(
        dayId,
        'row',
        1,
        sets: 4,
        reps: 12,
        durationSeconds: 600,
        distance: 2.5,
      );
      await seedScheduled(dayId, 'fly', 2);

      // The session: row moved first, bench done 3x8, fly swapped for dips.
      await repo.replaceScheduledExercises(dayId, [
        info('row', 0, sets: 2, reps: 20),
        info('bench', 1, sets: 3, reps: 8),
        info('dips', 2, sets: 2, reps: 15),
      ]);

      final rows = await scheduleDao.getExercises(dayId);
      expect(rows.map((r) => r.exerciseId).toList(), ['row', 'bench', 'dips']);
      expect(rows.map((r) => r.orderIndex).toList(), [0, 1, 2]);
      // Kept exercises keep their planned targets, cardio goals included.
      expect((rows[0].targetSets, rows[0].targetReps), (4, 12));
      expect(rows[0].targetDurationSeconds, 600);
      expect(rows[0].targetDistance, 2.5);
      expect((rows[1].targetSets, rows[1].targetReps), (5, 5));
      // The new exercise is planned from what was done today.
      expect((rows[2].targetSets, rows[2].targetReps), (2, 15));
      expect(rows[2].targetDurationSeconds, isNull);
      expect(rows[2].targetDistance, isNull);
    });

    test(
        'a duplicated exercise reuses the existing row once and plans the '
        'extra copy from the session', () async {
      final dayId = await seedDay(await seedSchedule());
      await seedScheduled(dayId, 'curl', 0, sets: 4, reps: 8);

      await repo.replaceScheduledExercises(dayId, [
        info('curl', 0, sets: 2, reps: 12),
        info('curl', 1, sets: 2, reps: 12),
      ]);

      final rows = await scheduleDao.getExercises(dayId);
      expect(
        rows.map((r) => (r.targetSets, r.targetReps)).toList(),
        [(4, 8), (2, 12)],
      );
    });

    test('other days are untouched', () async {
      final scheduleId = await seedSchedule();
      final dayId = await seedDay(scheduleId);
      final otherDay = await seedDay(scheduleId, index: 1);
      await seedScheduled(dayId, 'bench', 0);
      await seedScheduled(otherDay, 'squat', 0);

      await repo.replaceScheduledExercises(dayId, [info('dips', 0)]);

      expect(
        (await scheduleDao.getExercises(dayId)).map((r) => r.exerciseId),
        ['dips'],
      );
      expect(
        (await scheduleDao.getExercises(otherDay)).map((r) => r.exerciseId),
        ['squat'],
      );
    });
  });
}
