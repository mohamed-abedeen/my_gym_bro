import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Regression tests for the root back handling pattern used by
/// MyGymBroScaffold (BackButtonListener + PopScope).
///
/// go_router 13's popRoute() checks canPop() BEFORE maybePop(), so a
/// PopScope sitting on the root route is never consulted — the system back
/// would fall through and exit the app. The scaffold therefore intercepts
/// with a BackButtonListener (priority on the back dispatcher) and defers
/// to the router only when something is genuinely poppable.
void main() {
  Widget rootScreen({
    required Future<bool> Function(BuildContext) onBack,
  }) {
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

  testWidgets(
      'system back at the root reaches the BackButtonListener '
      '(go_router 13 would otherwise exit the app)', (tester) async {
    var handled = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => rootScreen(onBack: (context) async {
            if (GoRouter.of(context).canPop()) return false;
            handled++;
            return true; // consumed — app stays alive
          }),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    // Simulates the OS back event through the root back dispatcher.
    expect(await tester.binding.handlePopRoute(), isTrue,
        reason: 'the event must be consumed, not bubble to app-exit');
    expect(handled, 1);
  });

  testWidgets('with a pushed route, back pops it and the handler defers',
      (tester) async {
    var handled = 0;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => rootScreen(onBack: (context) async {
            if (GoRouter.of(context).canPop()) return false;
            handled++;
            return true;
          }),
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

    expect(find.text('pushed'), findsNothing,
        reason: 'back must pop the pushed route');
    expect(find.text('root'), findsOneWidget);
    expect(handled, 0,
        reason: 'the root handler must defer while a route is poppable');
  });
}
