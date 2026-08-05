import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/schedule_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/schedule/schedule_builder_screen.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

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

  Widget app(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
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
      final rest = days.singleWhere((day) => day.label == 'Rest');
      expect(rest.isRestDay, isTrue);
      expect(await scheduleDao.getExercises(rest.localId), isEmpty);
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

  test('ScheduleBuilderArgs retains schedule and initial day identifiers', () {
    const args = ScheduleBuilderArgs(scheduleId: 12, initialDayLocalId: 34);

    expect(args.scheduleId, 12);
    expect(args.initialDayLocalId, 34);
  });
}
