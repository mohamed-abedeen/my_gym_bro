import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
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

    test('watchById emits a schedule then null after deletion', () async {
      final scheduleId = await dao.createSchedule(
        SchedulesCompanion.insert(name: 'Upper lower'),
      );
      final initialEmission = Completer<void>();
      final deletionEmission = Completer<void>();
      var emissions = 0;
      Schedule? latest;
      final subscription = dao.watchById(scheduleId).listen((schedule) {
        emissions++;
        latest = schedule;
        if (emissions == 1) initialEmission.complete();
        if (schedule == null) deletionEmission.complete();
      });
      addTearDown(subscription.cancel);

      await initialEmission.future;
      expect(latest?.localId, scheduleId);

      final otherScheduleId = await dao.createSchedule(
        SchedulesCompanion.insert(name: 'Full body'),
      );
      await dao.updateSchedule(
        otherScheduleId,
        const SchedulesCompanion(name: Value('Full body revised')),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, 1);
      expect(latest?.localId, scheduleId);

      await dao.deleteSchedule(scheduleId);

      await deletionEmission.future;
      expect(emissions, 2);
      expect(latest, isNull);
    });
  });
}
