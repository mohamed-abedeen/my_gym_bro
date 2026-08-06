import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/schedule/schedule_builder_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

class _DelayedScheduleDao extends ScheduleDao {
  _DelayedScheduleDao(super.db, this._release);

  final Future<void> _release;

  @override
  Future<List<Schedule>> getAll() async {
    await _release;
    return super.getAll();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ScheduleDao scheduleDao;
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    scheduleDao = ScheduleDao(db);
  });

  tearDown(() => db.close());

  Widget app(Widget child, {ScheduleDao? scheduleDaoOverride}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      if (scheduleDaoOverride != null)
        scheduleDaoProvider.overrideWithValue(scheduleDaoOverride),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: const [AppColorsTheme.dark]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );

  Future<({int scheduleId, int pushId, int restId, int pullId})>
  seedSchedule() async {
    final scheduleId = await scheduleDao.createSchedule(
      SchedulesCompanion.insert(name: 'Three day split'),
    );
    final pushId = await scheduleDao.addDay(
      ScheduleDaysCompanion.insert(
        scheduleId: scheduleId,
        dayIndex: 0,
        label: const Value('Push'),
      ),
    );
    final restId = await scheduleDao.addDay(
      ScheduleDaysCompanion.insert(
        scheduleId: scheduleId,
        dayIndex: 1,
        label: const Value('Rest'),
        isRestDay: const Value(true),
      ),
    );
    final pullId = await scheduleDao.addDay(
      ScheduleDaysCompanion.insert(
        scheduleId: scheduleId,
        dayIndex: 2,
        label: const Value('Pull'),
      ),
    );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(exerciseId: 'bench', name: 'Bench press'),
        );
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(exerciseId: 'row', name: 'Barbell row'),
        );
    await scheduleDao.addExercise(
      ScheduledExercisesCompanion.insert(
        scheduleDayId: pushId,
        exerciseId: 'bench',
        orderIndex: 0,
      ),
    );
    await scheduleDao.addExercise(
      ScheduledExercisesCompanion.insert(
        scheduleDayId: pullId,
        exerciseId: 'row',
        orderIndex: 0,
      ),
    );
    return (
      scheduleId: scheduleId,
      pushId: pushId,
      restId: restId,
      pullId: pullId,
    );
  }

  Future<({int scheduleId, int targetDayId})> seedDays(int count) async {
    final scheduleId = await scheduleDao.createSchedule(
      SchedulesCompanion.insert(name: 'Long split'),
    );
    var targetDayId = -1;
    for (var index = 0; index < count; index++) {
      targetDayId = await scheduleDao.addDay(
        ScheduleDaysCompanion.insert(
          scheduleId: scheduleId,
          dayIndex: index,
          label: Value('Day ${index + 1}'),
        ),
      );
    }
    return (scheduleId: scheduleId, targetDayId: targetDayId);
  }

  testWidgets('focuses the requested existing training day after loading', (
    tester,
  ) async {
    final ids = await seedSchedule();

    await tester.pumpWidget(
      app(
        ScheduleBuilderScreen(
          scheduleId: ids.scheduleId,
          initialDayLocalId: ids.pullId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(Key('schedule_builder_day_${ids.pullId}')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('schedule_builder_day_content_${ids.pullId}')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('schedule_builder_day_${ids.pushId}')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('schedule_builder_day_content_${ids.pushId}')),
      findsNothing,
    );
  });

  testWidgets('scrolls a requested lower day into the phone viewport', (
    tester,
  ) async {
    final originalSize = tester.view.physicalSize;
    final originalDevicePixelRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(390, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalDevicePixelRatio;
    });
    final ids = await seedDays(8);

    await tester.pumpWidget(
      app(
        ScheduleBuilderScreen(
          scheduleId: ids.scheduleId,
          initialDayLocalId: ids.targetDayId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(Key('schedule_builder_day_${ids.targetDayId}')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .descendant(
            of: find.byKey(
              Key('schedule_builder_day_content_${ids.targetDayId}'),
            ),
            matching: find.text(l10n.day),
          )
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('renders a focused rest day without exercise editing controls', (
    tester,
  ) async {
    final ids = await seedSchedule();

    await tester.pumpWidget(
      app(
        ScheduleBuilderScreen(
          scheduleId: ids.scheduleId,
          initialDayLocalId: ids.restId,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final restContent = find.byKey(
      Key('schedule_builder_day_content_${ids.restId}'),
    );
    expect(
      find.byKey(Key('schedule_builder_day_${ids.restId}')),
      findsOneWidget,
    );
    expect(restContent, findsOneWidget);
    expect(find.text('Rest'), findsWidgets);
    expect(
      find.descendant(
        of: restContent,
        matching: find.byType(ReorderableListView),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: restContent,
        matching: find.byKey(
          Key('schedule_builder_add_exercise_${ids.restId}'),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'saving an existing schedule preserves rest rows without exercises',
    (tester) async {
      final ids = await seedSchedule();

      await tester.pumpWidget(
        app(
          ScheduleBuilderScreen(
            scheduleId: ids.scheduleId,
            initialDayLocalId: ids.pullId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(l10n.done));
      await tester.pumpAndSettle();

      final days = await scheduleDao.getDays(ids.scheduleId);
      expect(days.map((day) => day.label), ['Push', 'Rest', 'Pull']);
      expect(days.map((day) => day.isRestDay), [false, true, false]);
      final rest = days.singleWhere((day) => day.label == 'Rest');
      final push = days.singleWhere((day) => day.label == 'Push');
      final pull = days.singleWhere((day) => day.label == 'Pull');
      expect(rest.isRestDay, isTrue);
      expect(await scheduleDao.getExercises(rest.localId), isEmpty);
      final pushExercises = await scheduleDao.getExercises(push.localId);
      final pullExercises = await scheduleDao.getExercises(pull.localId);
      expect(pushExercises.single.exerciseId, 'bench');
      expect(pushExercises.single.targetSets, 3);
      expect(pushExercises.single.targetReps, 10);
      expect(pullExercises.single.exerciseId, 'row');
      expect(pullExercises.single.targetSets, 3);
      expect(pullExercises.single.targetReps, 10);
    },
  );

  testWidgets(
    'keeps unsaved day identity stable when a saved ID matches its index',
    (tester) async {
      final ids = await seedSchedule();

      await tester.pumpWidget(
        app(ScheduleBuilderScreen(scheduleId: ids.scheduleId)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.addDay));
      await tester.pumpAndSettle();
      expect(tester.takeException(), equals(null));

      final firstNewDay = find.byKey(const Key('schedule_builder_day_new-0'));
      expect(firstNewDay, findsOneWidget);

      await tester.tap(find.text(l10n.addDay));
      await tester.pumpAndSettle();
      expect(tester.takeException(), equals(null));

      final secondNewDay = find.byKey(const Key('schedule_builder_day_new-1'));
      expect(secondNewDay, findsOneWidget);

      await tester.tap(
        find.descendant(
          of: firstNewDay,
          matching: find.byIcon(Icons.calendar_today_rounded),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: firstNewDay,
          matching: find.byIcon(Icons.delete_outline_rounded),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), equals(null));
      expect(firstNewDay, findsNothing);
      expect(secondNewDay, findsOneWidget);
    },
  );

  testWidgets('does not write to a disposed schedule editor after loading', (
    tester,
  ) async {
    final ids = await seedSchedule();
    final release = Completer<void>();

    await tester.pumpWidget(
      app(
        ScheduleBuilderScreen(scheduleId: ids.scheduleId),
        scheduleDaoOverride: _DelayedScheduleDao(db, release.future),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    release.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), equals(null));
  });

  test('ScheduleBuilderArgs retains schedule and initial day identifiers', () {
    const args = ScheduleBuilderArgs(scheduleId: 12, initialDayLocalId: 34);

    expect(args.scheduleId, 12);
    expect(args.initialDayLocalId, 34);
  });

  test('converts schedule builder route extras compatibly', () {
    final none = scheduleBuilderArgsFromExtra(null);
    final legacy = scheduleBuilderArgsFromExtra(12);
    const explicit = ScheduleBuilderArgs(scheduleId: 23, initialDayLocalId: 45);

    expect(none.scheduleId, equals(null));
    expect(none.initialDayLocalId, equals(null));
    expect(legacy.scheduleId, 12);
    expect(legacy.initialDayLocalId, equals(null));
    expect(scheduleBuilderArgsFromExtra(explicit), same(explicit));
    expect(() => scheduleBuilderArgsFromExtra('invalid'), throwsArgumentError);
  });
}
