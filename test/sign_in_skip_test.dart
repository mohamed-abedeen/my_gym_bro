import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/exercise_api_service.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';
import 'package:my_gym_bro/features/auth/sign_in_screen.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// Until sign-in is fully set up, debug and TestFlight (`BETA_FREE`) builds
/// can skip Sign In like the onboarding's other Skips. Tests run in debug.
void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Skip on Sign In enters the app without an account',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final router = GoRouter(
      initialLocation: AppRoutes.signIn,
      routes: [
        GoRoute(
          path: AppRoutes.signIn,
          builder: (_, __) => const SignInScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // No catalogue warm-up (network) in a test.
          exerciseRepositoryProvider.overrideWithValue(
            ExerciseRepository(ExerciseApiService(), ExerciseDao(db)),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppColorsTheme.dark]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.ensureVisible(find.text(l10n.skip));
    await tester.tap(find.text(l10n.skip));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });
}
