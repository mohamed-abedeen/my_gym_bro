import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';

Stream<List<ScheduledExercise>> _watchRawExercisesForSchedule(
  AppDatabase db,
  int scheduleId,
) {
  final query =
      db.select(db.scheduledExercises).join([
          innerJoin(
            db.scheduleDays,
            db.scheduleDays.localId.equalsExp(
              db.scheduledExercises.scheduleDayId,
            ),
          ),
        ])
        ..where(db.scheduleDays.scheduleId.equals(scheduleId))
        ..orderBy([
          OrderingTerm.asc(db.scheduleDays.dayIndex),
          OrderingTerm.asc(db.scheduleDays.localId),
          OrderingTerm.asc(db.scheduledExercises.orderIndex),
          OrderingTerm.asc(db.scheduledExercises.localId),
        ]);

  return query.watch().map(
    (rows) => rows
        .map((row) => row.readTable(db.scheduledExercises))
        .toList(growable: false),
  );
}

void main() {
  group('ScheduleDao current split streams', () {
    late AppDatabase db;
    late ScheduleDao dao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = ScheduleDao(db);
    });

    tearDown(() => db.close());

    test(
      'watchExercisesForSchedule reacts to exercises across its days',
      () async {
        final scheduleId = await dao.createSchedule(
          SchedulesCompanion.insert(name: 'Push pull legs'),
        );
        final firstDayId = await dao.addDay(
          ScheduleDaysCompanion.insert(scheduleId: scheduleId, dayIndex: 0),
        );
        final secondDayId = await dao.addDay(
          ScheduleDaysCompanion.insert(scheduleId: scheduleId, dayIndex: 0),
        );
        final firstExerciseId = await dao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: firstDayId,
            exerciseId: 'row',
            orderIndex: 1,
          ),
        );

        final iterator = StreamIterator(
          dao.watchExercisesForSchedule(scheduleId),
        );
        addTearDown(iterator.cancel);

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.map((exercise) => exercise.localId), [
          firstExerciseId,
        ]);

        final secondExerciseId = await dao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: secondDayId,
            exerciseId: 'bench',
            orderIndex: 0,
          ),
        );

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.map((exercise) => exercise.localId), [
          firstExerciseId,
          secondExerciseId,
        ]);
      },
    );

    test(
      'watchExercisesForSchedule orders every deterministic tie-break',
      () async {
        final scheduleId = await dao.createSchedule(
          SchedulesCompanion.insert(name: 'Tie-break split'),
        );
        final firstDayId = await dao.addDay(
          ScheduleDaysCompanion.insert(scheduleId: scheduleId, dayIndex: 0),
        );
        final secondDayId = await dao.addDay(
          ScheduleDaysCompanion.insert(scheduleId: scheduleId, dayIndex: 0),
        );
        final secondDayExerciseId = await dao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: secondDayId,
            exerciseId: 'second-day-first',
            orderIndex: 0,
          ),
        );
        final firstDayLaterExerciseId = await dao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: firstDayId,
            exerciseId: 'first-day-later',
            orderIndex: 1,
          ),
        );
        final firstDayFirstExerciseId = await dao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: firstDayId,
            exerciseId: 'first-day-first',
            orderIndex: 0,
          ),
        );
        final firstDayTiedExerciseId = await dao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: firstDayId,
            exerciseId: 'first-day-tied',
            orderIndex: 0,
          ),
        );

        final exercises = await dao.watchExercisesForSchedule(scheduleId).first;

        expect(exercises.map((exercise) => exercise.localId), [
          firstDayFirstExerciseId,
          firstDayTiedExerciseId,
          firstDayLaterExerciseId,
          secondDayExerciseId,
        ]);
      },
    );

    test(
      'watchExercisesForSchedule ignores unrelated schedule mutations',
      () async {
        final scheduleId = await dao.createSchedule(
          SchedulesCompanion.insert(name: 'Watched split'),
        );
        final scheduleDayId = await dao.addDay(
          ScheduleDaysCompanion.insert(scheduleId: scheduleId, dayIndex: 0),
        );
        final otherScheduleId = await dao.createSchedule(
          SchedulesCompanion.insert(name: 'Other split'),
        );
        final initialEmission = Completer<void>();
        final relatedEmission = Completer<void>();
        final emissions = <List<int>>[];
        final subscription = dao.watchExercisesForSchedule(scheduleId).listen((
          exercises,
        ) {
          final ids = exercises
              .map((exercise) => exercise.localId)
              .toList(growable: false);
          emissions.add(ids);
          if (emissions.length == 1) initialEmission.complete();
          if (ids.isNotEmpty) relatedEmission.complete();
        });
        addTearDown(subscription.cancel);

        await initialEmission.future;
        final rawIterator = StreamIterator(
          _watchRawExercisesForSchedule(db, scheduleId),
        );
        addTearDown(rawIterator.cancel);
        expect(await rawIterator.moveNext(), isTrue);
        expect(rawIterator.current, isEmpty);

        final otherDayId = await dao.addDay(
          ScheduleDaysCompanion.insert(
            scheduleId: otherScheduleId,
            dayIndex: 0,
          ),
        );
        expect(await rawIterator.moveNext(), isTrue);
        expect(rawIterator.current, isEmpty);

        await dao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: otherDayId,
            exerciseId: 'unrelated',
            orderIndex: 0,
          ),
        );
        expect(await rawIterator.moveNext(), isTrue);
        expect(rawIterator.current, isEmpty);

        final relatedExerciseId = await dao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: scheduleDayId,
            exerciseId: 'related',
            orderIndex: 0,
          ),
        );

        await relatedEmission.future;
        expect(emissions, [
          <int>[],
          [relatedExerciseId],
        ]);
      },
    );

    test('watchById emits a schedule then null after deletion', () async {
      final scheduleId = await dao.createSchedule(
        SchedulesCompanion.insert(name: 'Upper lower'),
      );
      final initialEmission = Completer<void>();
      final deletionEmission = Completer<void>();
      final emissions = <int?>[];
      Schedule? latest;
      final subscription = dao.watchById(scheduleId).listen((schedule) {
        emissions.add(schedule?.localId);
        latest = schedule;
        if (emissions.length == 1) initialEmission.complete();
        if (schedule == null) deletionEmission.complete();
      });
      addTearDown(subscription.cancel);

      await initialEmission.future;
      expect(latest?.localId, scheduleId);
      final rawIterator = StreamIterator(
        (db.select(db.schedules)
              ..where((table) => table.localId.equals(scheduleId)))
            .watchSingleOrNull(),
      );
      addTearDown(rawIterator.cancel);
      expect(await rawIterator.moveNext(), isTrue);
      expect(rawIterator.current?.localId, scheduleId);

      final otherScheduleId = await dao.createSchedule(
        SchedulesCompanion.insert(name: 'Full body'),
      );
      expect(await rawIterator.moveNext(), isTrue);
      expect(rawIterator.current?.localId, scheduleId);

      await dao.updateSchedule(
        otherScheduleId,
        const SchedulesCompanion(name: Value('Full body revised')),
      );
      expect(await rawIterator.moveNext(), isTrue);
      expect(rawIterator.current?.localId, scheduleId);

      await dao.deleteSchedule(scheduleId);

      await deletionEmission.future;
      expect(emissions, [scheduleId, null]);
      expect(latest, isNull);
    });
  });
}
