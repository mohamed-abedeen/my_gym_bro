import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';

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
          ScheduleDaysCompanion.insert(scheduleId: scheduleId, dayIndex: 1),
        );
        final firstExerciseId = await dao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: secondDayId,
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
            scheduleDayId: firstDayId,
            exerciseId: 'bench',
            orderIndex: 0,
          ),
        );

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.map((exercise) => exercise.localId), [
          secondExerciseId,
          firstExerciseId,
        ]);
      },
    );

    test('watchById emits a schedule then null after deletion', () async {
      final scheduleId = await dao.createSchedule(
        SchedulesCompanion.insert(name: 'Upper lower'),
      );
      final iterator = StreamIterator(dao.watchById(scheduleId));
      addTearDown(iterator.cancel);

      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current?.localId, scheduleId);

      await dao.deleteSchedule(scheduleId);

      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isNull);
    });
  });
}
