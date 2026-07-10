import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/app.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/core/services/crash_reporter.dart';
import 'package:my_gym_bro/core/services/exercise_api_service.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';
import 'package:my_gym_bro/core/services/notification_service.dart';
import 'package:my_gym_bro/core/services/program_seeder.dart';
import 'package:my_gym_bro/core/services/subscription_sync_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  runZonedGuarded<void>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await _bootstrap();
  }, (error, stack) {
    CrashReporter.recordError(
      error,
      stackTrace: stack,
      reason: 'Uncaught zone error',
      fatal: true,
    );
  });
}

Future<void> _bootstrap() async {
  final stopwatch = Stopwatch()..start();
  void mark(String step) =>
      debugPrint('[bootstrap] $step (+${stopwatch.elapsedMilliseconds}ms)');

  mark('start');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  mark('orientation set');

  // Firebase + crash handlers — fast, local init.
  // No Firebase config (google-services.json / firebase_options.dart) means
  // initializeApp() throws; that's non-fatal, the app runs without Firebase.
  // We log only a one-liner — dumping the full native stacktrace floods
  // debugPrint's throttle and swallows later logs.
  try {
    mark('firebase init begin');
    await Firebase.initializeApp();
    mark('firebase init done');
    if (!kDebugMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  } on Object catch (_) {
    // Catch everything: an unconfigured Firebase throws an Error, not only an
    // Exception. Non-fatal — the app runs without Firebase.
    mark('firebase init skipped (not configured)');
  }

  // Supabase — bounded so a slow/absent network can't stall startup.
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      mark('supabase init begin');
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)
          .timeout(const Duration(seconds: 10));
      mark('supabase init done');
    } on Exception catch (_) {
      // Unreachable or timed out — app runs in local/offline mode.
    }
  }

  // RevenueCat — skipped on placeholder keys.
  final rcKey = Platform.isIOS
      ? const String.fromEnvironment('REVENUECAT_IOS_KEY')
      : const String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  if (rcKey.isNotEmpty && !rcKey.startsWith('your-')) {
    try {
      mark('revenuecat configure begin');
      await Purchases.configure(PurchasesConfiguration(rcKey));
      mark('revenuecat configure done');
    } on Exception catch (_) {
      // RevenueCat not configured yet.
    }
  }

  // ── Fast local reads needed before the first frame ──
  // Wrapped so a DB-open / migration / secure-storage failure degrades to
  // defaults instead of throwing out of _bootstrap() and freezing the splash.
  final secureStorage = SecureStorage();
  mark('db create begin');
  final db = AppDatabase.create();

  Locale? savedLocale;
  ThemeMode? savedTheme;
  int? lastScheduleId;
  try {
    final profile = await UserProfileDao(db).getFirst();
    mark('profile read done');
    if (profile != null && profile.preferredLanguage != 'system') {
      savedLocale = Locale(profile.preferredLanguage);
    }

    final themeStr = await secureStorage.read('theme_mode');
    mark('theme read done');
    if (themeStr == 'ThemeMode.light') {
      savedTheme = ThemeMode.light;
    } else if (themeStr == 'ThemeMode.dark') {
      savedTheme = ThemeMode.dark;
    }

    final lastScheduleStr =
        await secureStorage.read('last_selected_schedule_id');
    lastScheduleId =
        lastScheduleStr != null ? int.tryParse(lastScheduleStr) : null;
  } on Object catch (error, stack) {
    CrashReporter.recordError(error, stackTrace: stack, reason: 'Startup reads failed');
  }
  mark('reads done -- calling runApp');

  // ── Render immediately — splash is visible from this point ──
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        localeProvider.overrideWith((ref) => savedLocale),
        if (savedTheme != null)
          themeModeProvider.overrideWith((ref) => savedTheme!),
        if (lastScheduleId != null)
          workoutCardStateProvider.overrideWith(
            (ref) => WorkoutCardState(selectedScheduleId: lastScheduleId),
          ),
      ],
      child: const MyGymBroApp(),
    ),
  );

  // ── Network- and permission-bound work runs AFTER the first frame ──
  // Notification init triggers FCM getToken() and OS permission prompts,
  // which can block indefinitely on a slow/absent network. Awaiting it
  // before runApp() froze the splash, so it is now fire-and-forget.
  unawaited(NotificationService.initialise());
  unawaited(_backgroundDbInit(db));

  // Reconcile RevenueCat entitlements into the local profile on launch, and
  // keep them in sync as renewals/cancellations arrive. Best-effort — both
  // no-op when RevenueCat isn't configured.
  final profileDao = UserProfileDao(db);
  SubscriptionSyncService.listen(profileDao);
  unawaited(SubscriptionSyncService.syncNow(profileDao));

  mark('runApp returned -- bootstrap complete');
}

/// Seeds and migrates the database after [runApp] so the main thread is never
/// blocked waiting for these operations.
Future<void> _backgroundDbInit(AppDatabase db) async {
  // Throwaway API client + repository used only for startup seeding; the UI
  // uses the repository from `exerciseRepositoryProvider` instead.
  final exerciseApi = ExerciseApiService();
  final exerciseRepo = ExerciseRepository(exerciseApi, ExerciseDao(db));
  try {
    // Exercises are no longer bulk-seeded in full; they sync from the
    // ExerciseDB OSS API and are cached on demand. Seed only the tiny starter
    // set so the default program has rich data offline on first launch.
    final programSeeder = ProgramSeeder(db, exerciseRepo);
    await programSeeder.ensureStarterCached();
    await programSeeder.seedIfNeeded();
  } on Exception catch (e, stack) {
    CrashReporter.recordError(e,
        stackTrace: stack, reason: 'Background DB init failed');
  } finally {
    exerciseApi.dispose();
  }
}
