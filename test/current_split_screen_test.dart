import 'dart:ui' show SemanticsAction;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/schedule/schedule_builder_screen.dart';
import 'package:my_gym_bro/features/workout/current_split/current_split_providers.dart';
import 'package:my_gym_bro/features/workout/reports_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/features/workout/workout_screen.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const localNotificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localNotificationsChannel, (_) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localNotificationsChannel, null);
  });

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        streakProvider.overrideWith((ref) async => 0),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget app() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ThemeData(extensions: const [AppColorsTheme.dark]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: WorkoutScreen()),
    ),
  );

  Widget routerApp(GoRouter router) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: ThemeData(extensions: const [AppColorsTheme.dark]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );

  Future<int> seedSelectedSchedule() async {
    final scheduleId = await container
        .read(scheduleDaoProvider)
        .createSchedule(SchedulesCompanion.insert(name: 'Compact plan'));
    await container
        .read(scheduleDaoProvider)
        .addDay(
          ScheduleDaysCompanion.insert(
            scheduleId: scheduleId,
            dayIndex: 0,
            label: const Value('Compact day'),
          ),
        );
    container.read(workoutCardStateProvider.notifier).state = WorkoutCardState(
      selectedScheduleId: scheduleId,
    );
    return scheduleId;
  }

  Future<void> pumpUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('opens the currently displayed schedule from a populated day', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final activeId = await container
        .read(scheduleDaoProvider)
        .createSchedule(
          SchedulesCompanion.insert(
            name: 'Active plan',
            isActive: const Value(true),
          ),
        );
    final selectedId = await container
        .read(scheduleDaoProvider)
        .createSchedule(
          SchedulesCompanion.insert(name: 'Picker-selected plan'),
        );
    await container
        .read(scheduleDaoProvider)
        .addDay(
          ScheduleDaysCompanion.insert(
            scheduleId: selectedId,
            dayIndex: 0,
            label: const Value('Selected day'),
          ),
        );
    container.read(workoutCardStateProvider.notifier).state = WorkoutCardState(
      selectedScheduleId: selectedId,
    );

    await tester.pumpWidget(app());
    await pumpUi(tester);

    expect(activeId, isNot(selectedId));
    expect(find.text('Picker-selected plan'), findsOneWidget);
    final openButton = find.byKey(const Key('current_split_open_button'));
    expect(openButton, findsOneWidget);
    final openSemantics = tester.getSemantics(openButton).getSemanticsData();
    expect(
      openSemantics.label,
      AppLocalizations.of(tester.element(openButton)).openCurrentSplit,
    );
    expect(openSemantics.flagsCollection.isButton, isTrue);
    expect(
      find.descendant(
        of: openButton,
        matching: find.byIcon(Icons.search_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.edit_rounded), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.byIcon(Icons.search),
      findsOneWidget,
      reason: 'the Add Day card keeps its exercise search control',
    );

    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(openButton);
    await pumpUi(tester);

    expect(find.byKey(const Key('current_split_screen')), findsOneWidget);
    expect(container.read(currentSplitScheduleIdProvider), selectedId);
    final backSemantics = tester
        .getSemantics(find.byKey(const Key('current_split_back_button')))
        .getSemanticsData();
    expect(
      backSemantics.label,
      AppLocalizations.of(
        tester.element(find.byKey(const Key('current_split_back_button'))),
      ).back,
    );
    expect(backSemantics.flagsCollection.isButton, isTrue);

    await tester.tap(find.byKey(const Key('current_split_back_button')));
    await tester.pump();

    expect(find.byKey(const Key('current_split_screen')), findsNothing);
    expect(find.byKey(const Key('current_split_open_button')), findsOneWidget);
    expect(container.read(currentSplitScheduleIdProvider), isNull);
    semanticsHandle.dispose();
  });

  testWidgets(
    'keeps the current split entry at least 44 by 44 logical pixels',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await seedSelectedSchedule();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColorsTheme.dark]),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                Responsive.init(context);
                return const Scaffold(
                  body: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 1000,
                    maxHeight: 1000,
                    child: SizedBox(
                      width: 800,
                      height: 1000,
                      child: WorkoutScreen(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(
        find.byKey(const Key('current_split_open_button')),
      );
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    },
  );

  testWidgets(
    'shows the current split overview hierarchy and its real anatomy body',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final scheduleId = await seedSelectedSchedule();
      await container
          .read(scheduleDaoProvider)
          .addDay(
            ScheduleDaysCompanion.insert(
              scheduleId: scheduleId,
              dayIndex: 1,
              label: const Value('Rest'),
              isRestDay: const Value(true),
            ),
          );
      container.read(currentSplitScheduleIdProvider.notifier).state =
          scheduleId;

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const WorkoutScreen()),
          GoRoute(
            path: AppRoutes.scheduleBuilder,
            builder: (_, _) => const SizedBox(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const SizedBox(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(routerApp(router));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('current_split_hero')), findsOneWidget);
      expect(find.byType(AnatomyBody), findsOneWidget);
      expect(find.byKey(const Key('current_split_metrics')), findsOneWidget);
      expect(
        find.byKey(const Key('current_split_quick_actions')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('current_split_plan_heading')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('current_split_day_1')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('current_split_metrics'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('current_split_quick_actions')))
              .dy,
        ),
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('current_split_quick_actions')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('current_split_plan_heading')))
              .dy,
        ),
      );
      final progress = find.byKey(const Key('current_split_action_progress'));
      final nutrition = find.byKey(const Key('current_split_action_nutrition'));
      final statistics = find.byKey(
        const Key('current_split_action_statistics'),
      );
      final settings = find.byKey(const Key('current_split_action_settings'));
      expect(
        tester.getTopLeft(progress).dx,
        lessThan(tester.getTopLeft(nutrition).dx),
      );
      expect(
        tester.getTopLeft(statistics).dy,
        greaterThan(tester.getTopLeft(progress).dy),
      );
      expect(
        tester.getTopLeft(settings).dx,
        greaterThan(tester.getTopLeft(statistics).dx),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('current_split_day_2')),
        220,
      );
      expect(find.byKey(const Key('current_split_day_2')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('current_split_discover_disabled')),
        220,
      );
      expect(
        find.byKey(const Key('current_split_discover_disabled')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'navigates current split edit and day actions with schedule extras',
    (tester) async {
      final scheduleId = await seedSelectedSchedule();
      container.read(currentSplitScheduleIdProvider.notifier).state =
          scheduleId;
      Object? scheduleBuilderExtra;
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const WorkoutScreen()),
          GoRoute(
            path: AppRoutes.scheduleBuilder,
            builder: (_, state) {
              scheduleBuilderExtra = state.extra;
              return const SizedBox();
            },
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const SizedBox(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(routerApp(router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('current_split_edit_button')));
      await tester.pumpAndSettle();
      expect(
        scheduleBuilderExtra,
        isA<ScheduleBuilderArgs>()
            .having((args) => args.scheduleId, 'schedule id', scheduleId)
            .having((args) => args.initialDayLocalId, 'initial day', isNull),
      );

      router.go('/');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('current_split_day_1')),
        220,
      );
      await tester.tap(find.byKey(const Key('current_split_day_1')));
      await tester.pumpAndSettle();
      expect(
        scheduleBuilderExtra,
        isA<ScheduleBuilderArgs>()
            .having((args) => args.scheduleId, 'schedule id', scheduleId)
            .having((args) => args.initialDayLocalId, 'initial day', 1),
      );
    },
  );

  testWidgets('marks nutrition disabled and opens settings', (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final scheduleId = await seedSelectedSchedule();
    container.read(currentSplitScheduleIdProvider.notifier).state = scheduleId;
    var openedSettings = false;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const WorkoutScreen()),
        GoRoute(
          path: AppRoutes.scheduleBuilder,
          builder: (_, _) => const SizedBox(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, _) {
            openedSettings = true;
            return const SizedBox();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(routerApp(router));
    await tester.pumpAndSettle();

    final nutrition = find.byKey(const Key('current_split_action_nutrition'));
    expect(
      tester
          .getSemantics(nutrition)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    final settings = find.byKey(const Key('current_split_action_settings'));
    await Scrollable.ensureVisible(tester.element(settings), alignment: 0.5);
    await tester.pump();
    final settingsCenter = tester.getCenter(settings);
    final viewport = tester.getRect(find.byType(CustomScrollView));
    expect(viewport.contains(settingsCenter), isTrue);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(openedSettings, isTrue);
    semanticsHandle.dispose();
  });

  testWidgets('opens reports from the current split progress action', (
    tester,
  ) async {
    final scheduleId = await seedSelectedSchedule();
    container.read(currentSplitScheduleIdProvider.notifier).state = scheduleId;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const WorkoutScreen()),
        GoRoute(
          path: AppRoutes.scheduleBuilder,
          builder: (_, _) => const SizedBox(),
        ),
        GoRoute(path: AppRoutes.settings, builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(routerApp(router));
    await tester.pumpAndSettle();

    final progress = find.byKey(const Key('current_split_action_progress'));
    expect(
      tester
          .getSemantics(progress)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(progress);
    await tester.pumpAndSettle();
    expect(find.byType(ReportsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('current split overview has no overflow at target phone sizes', (
    tester,
  ) async {
    final scheduleId = await seedSelectedSchedule();
    container.read(currentSplitScheduleIdProvider.notifier).state = scheduleId;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const WorkoutScreen()),
        GoRoute(
          path: AppRoutes.scheduleBuilder,
          builder: (_, _) => const SizedBox(),
        ),
        GoRoute(path: AppRoutes.settings, builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(390, 844), Size(430, 932)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(routerApp(router));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('current_split_discover_disabled')),
        240,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'at ${size.width}x${size.height}',
      );
    }
  });
}
