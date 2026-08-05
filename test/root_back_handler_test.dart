import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/scaffold/my_gym_bro_scaffold.dart';
import 'package:my_gym_bro/features/workout/current_split/current_split_providers.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/bottom_nav_pill.dart';

/// Regression tests for the root back handling pattern used by
/// MyGymBroScaffold (BackButtonListener + PopScope).
///
/// go_router 13's popRoute() checks canPop() BEFORE maybePop(), so a
/// PopScope sitting on the root route is never consulted — the system back
/// would fall through and exit the app. The scaffold therefore intercepts
/// with a BackButtonListener (priority on the back dispatcher) and defers
/// to the router only when something is genuinely poppable.
void main() {
  Widget rootScreen({required Future<bool> Function(BuildContext) onBack}) {
    return Builder(
      builder: (context) => BackButtonListener(
        onBackButtonPressed: () => onBack(context),
        child: const PopScope(
          canPop: false,
          child: Scaffold(body: Text('root')),
        ),
      ),
    );
  }

  testWidgets('system back at the root reaches the BackButtonListener '
      '(go_router 13 would otherwise exit the app)', (tester) async {
    var handled = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => rootScreen(
            onBack: (context) async {
              if (GoRouter.of(context).canPop()) return false;
              handled++;
              return true; // consumed — app stays alive
            },
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    // Simulates the OS back event through the root back dispatcher.
    expect(
      await tester.binding.handlePopRoute(),
      isTrue,
      reason: 'the event must be consumed, not bubble to app-exit',
    );
    expect(handled, 1);
  });

  testWidgets('with a pushed route, back pops it and the handler defers', (
    tester,
  ) async {
    var handled = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => rootScreen(
            onBack: (context) async {
              if (GoRouter.of(context).canPop()) return false;
              handled++;
              return true;
            },
          ),
          routes: [
            GoRoute(
              path: 'pushed',
              builder: (_, __) => const Scaffold(body: Text('pushed')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    unawaited(router.push('/pushed'));
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(
      find.text('pushed'),
      findsNothing,
      reason: 'back must pop the pushed route',
    );
    expect(find.text('root'), findsOneWidget);
    expect(
      handled,
      0,
      reason: 'the root handler must defer while a route is poppable',
    );
  });

  testWidgets(
    'first system back from the workout current split stays in Workout',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          navIndexProvider.overrideWith((ref) => 1),
          currentSplitScheduleIdProvider.overrideWith((ref) => 42),
          streakProvider.overrideWith((ref) async => 0),
          widgetSyncProvider.overrideWith((ref) {}),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => const MyGymBroScaffold()),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: ThemeData(extensions: const [AppColorsTheme.dark]),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      expect(container.read(currentSplitScheduleIdProvider), isNull);
      expect(container.read(navIndexProvider), 1);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      expect(container.read(navIndexProvider), 0);
    },
  );
}
