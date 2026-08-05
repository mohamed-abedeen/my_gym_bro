import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/workout/current_split/current_split_providers.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/features/workout/workout_screen.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    expect(
      find.byIcon(Icons.search),
      findsOneWidget,
      reason: 'the Add Day card keeps its exercise search control',
    );

    await tester.drag(find.byType(PageView), const Offset(600, 0));
    await tester.pumpAndSettle();

    await tester.tap(openButton);
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();

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
}
