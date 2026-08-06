import 'dart:async';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/workout/current_split/current_split_models.dart';
import 'package:my_gym_bro/features/workout/current_split/current_split_providers.dart';

class _OverviewProbe {
  _OverviewProbe(ProviderContainer container, int scheduleId) {
    _subscription = container.listen<AsyncValue<CurrentSplitOverviewData?>>(
      currentSplitOverviewProvider(scheduleId),
      (_, next) {
        if (next.hasValue) _values.add(next.value);
      },
      fireImmediately: true,
    );
  }

  final _values = StreamController<CurrentSplitOverviewData?>.broadcast();
  late final ProviderSubscription<AsyncValue<CurrentSplitOverviewData?>>
  _subscription;

  Future<CurrentSplitOverviewData?> nextWhere(
    bool Function(CurrentSplitOverviewData? value) predicate,
  ) => _values.stream.firstWhere(predicate);

  Future<void> close() async {
    _subscription.close();
    await _values.close();
  }
}

void main() {
  group('current split providers', () {
    late AppDatabase db;
    late ProviderContainer container;
    late ScheduleDao scheduleDao;
    late ExerciseDao exerciseDao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      scheduleDao = ScheduleDao(db);
      exerciseDao = ExerciseDao(db);
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('derived per-ID providers are auto-dispose families', () {
      expect(
        scheduleByIdProvider(1),
        isA<AutoDisposeStreamProvider<Schedule?>>(),
      );
      expect(
        scheduledExercisesForScheduleProvider(1),
        isA<AutoDisposeStreamProvider<List<ScheduledExercise>>>(),
      );
      expect(
        currentSplitOverviewProvider(1),
        isA<AutoDisposeFutureProvider<CurrentSplitOverviewData?>>(),
      );
      expect(
        exerciseMetadataForIdsProvider('["bench"]'),
        isA<AutoDisposeStreamProvider<List<Exercise>>>(),
      );
      expect(currentSplitScheduleIdProvider, isA<StateProvider<int?>>());
    });

    test('uses the requested schedule ahead of the active schedule', () async {
      final requestedId = await scheduleDao.createSchedule(
        SchedulesCompanion.insert(name: 'Requested'),
      );
      await scheduleDao.createSchedule(
        SchedulesCompanion.insert(name: 'Active', isActive: const Value(true)),
      );

      final overview = await container.read(
        currentSplitOverviewProvider(requestedId).future,
      );

      expect(overview?.schedule.localId, requestedId);
      expect(overview?.schedule.name, 'Requested');
    });

    test(
      'falls back to the active schedule when requested ID is missing',
      () async {
        final activeId = await scheduleDao.createSchedule(
          SchedulesCompanion.insert(
            name: 'Active',
            isActive: const Value(true),
          ),
        );

        final overview = await container.read(
          currentSplitOverviewProvider(activeId + 1000).future,
        );

        expect(overview?.schedule.localId, activeId);
      },
    );

    test(
      'returns null when neither requested nor active schedule exists',
      () async {
        final overview = await container.read(
          currentSplitOverviewProvider(404).future,
        );

        expect(overview, isNull);
      },
    );

    test(
      'falls back reactively when the requested schedule is deleted',
      () async {
        final requestedId = await scheduleDao.createSchedule(
          SchedulesCompanion.insert(name: 'Requested'),
        );
        final activeId = await scheduleDao.createSchedule(
          SchedulesCompanion.insert(
            name: 'Active',
            isActive: const Value(true),
          ),
        );
        final probe = _OverviewProbe(container, requestedId);
        addTearDown(probe.close);

        final initial = await probe.nextWhere(
          (overview) => overview?.schedule.localId == requestedId,
        );
        expect(initial?.schedule.localId, requestedId);

        final fallback = probe.nextWhere(
          (overview) => overview?.schedule.localId == activeId,
        );
        await scheduleDao.deleteSchedule(requestedId);

        expect((await fallback)?.schedule.localId, activeId);
      },
    );

    test(
      'reacts to day, scheduled exercise, and exercise metadata mutations',
      () async {
        final scheduleId = await scheduleDao.createSchedule(
          SchedulesCompanion.insert(name: 'Reactive'),
        );
        final probe = _OverviewProbe(container, scheduleId);
        addTearDown(probe.close);

        final empty = await probe.nextWhere(
          (overview) => overview?.schedule.localId == scheduleId,
        );
        expect(empty?.days, isEmpty);

        final withDay = probe.nextWhere(
          (overview) => overview?.days.length == 1,
        );
        final dayId = await scheduleDao.addDay(
          ScheduleDaysCompanion.insert(scheduleId: scheduleId, dayIndex: 0),
        );
        expect((await withDay)?.totalExerciseCount, 0);

        final withScheduledExercise = probe.nextWhere(
          (overview) => overview?.totalExerciseCount == 1,
        );
        await scheduleDao.addExercise(
          ScheduledExercisesCompanion.insert(
            scheduleDayId: dayId,
            exerciseId: 'bench',
            orderIndex: 0,
          ),
        );
        expect((await withScheduledExercise)?.plannedMuscleGroups, isEmpty);

        final withInsertedMetadata = probe.nextWhere(
          (overview) =>
              overview?.plannedMuscleGroups.contains('Chest') ?? false,
        );
        await db
            .into(db.exercises)
            .insert(
              ExercisesCompanion.insert(
                exerciseId: 'bench',
                name: 'Bench press',
                muscleGroup: const Value('Chest'),
              ),
            );
        expect((await withInsertedMetadata)?.plannedMuscleGroups, {'Chest'});

        final withUpdatedMetadata = probe.nextWhere(
          (overview) => overview?.plannedMuscleGroups.contains('Back') ?? false,
        );
        await exerciseDao.updateMuscleGroup('bench', 'Back');
        final updated = await withUpdatedMetadata;
        expect(updated?.plannedMuscleGroups, {'Back'});
        expect(updated?.anatomyMuscles.single.muscleGroup, 'Back');
      },
    );
  });
}
