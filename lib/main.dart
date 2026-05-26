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
import 'package:my_gym_bro/core/services/notification_service.dart';
import 'package:my_gym_bro/core/services/exercise_local_service.dart';
import 'package:my_gym_bro/core/services/program_seeder.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/shared/app_constants.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock to portrait
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Firebase — skipped if not yet configured
    try {
      await Firebase.initializeApp();
      if (!kDebugMode) {
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('[Firebase] Init failed: $e');
      // Non-debug: Firebase misconfigured — Crashlytics won't be available
    }

    // Supabase — secrets from .env via --dart-define-from-file=.env
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      try {
        await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey)
            .timeout(const Duration(seconds: 10));
      } on Exception catch (_) {
        // Supabase not reachable or timed out — app works offline
      }
    }

    // RevenueCat — skipped if keys are placeholders
    final rcKey = Platform.isIOS
        ? const String.fromEnvironment('REVENUECAT_IOS_KEY')
        : const String.fromEnvironment('REVENUECAT_ANDROID_KEY');
    if (rcKey.isNotEmpty && !rcKey.startsWith('your-')) {
      try {
        await Purchases.configure(PurchasesConfiguration(rcKey));
      } on Exception catch (_) {
        // RevenueCat not configured yet
      }
    }

    // Initialise local notifications and request OS permissions.
    // Done before runApp so channels exist before any session is started.
    await NotificationService.initialise();

    // ── Fast reads — needed before first frame ──────────────────────────────
    final secureStorage = SecureStorage();
    final db = AppDatabase.create();

    final userProfileDao = UserProfileDao(db);
    final profile = await userProfileDao.getFirst();
    Locale? savedLocale;
    if (profile != null && profile.preferredLanguage != 'system') {
      savedLocale = Locale(profile.preferredLanguage);
    }

    final themeStr = await secureStorage.read('theme_mode');
    ThemeMode? savedTheme;
    if (themeStr == 'ThemeMode.light') {
      savedTheme = ThemeMode.light;
    } else if (themeStr == 'ThemeMode.dark') {
      savedTheme = ThemeMode.dark;
    }

    final lastScheduleStr = await secureStorage.read('last_selected_schedule_id');
    final lastScheduleId = lastScheduleStr != null ? int.tryParse(lastScheduleStr) : null;

    // ── Start the app — splash is visible from this point ──────────────────
    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          localeProvider.overrideWith((ref) => savedLocale),
          if (savedTheme != null)
            themeModeProvider.overrideWith((ref) => savedTheme!),
          if (lastScheduleId != null)
            workoutCardStateProvider.overrideWith((ref) => WorkoutCardState(selectedScheduleId: lastScheduleId)),
        ],
        child: const MyGymBroApp(),
      ),
    );

    // ── Heavy DB work runs AFTER the app is visible ─────────────────────────
    // Fire-and-forget: the splash screen's 1.5s delay gives these time to
    // complete before the user reaches any data-driven screen.
    unawaited(_backgroundDbInit(db, secureStorage));
  }, (error, stack) {
    if (Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

/// Seeds and migrates the database after [runApp] so the main thread is never
/// blocked waiting for these operations.
Future<void> _backgroundDbInit(
    AppDatabase db, SecureStorage secureStorage) async {
  try {
    // Seed exercises on first install
    final exerciseDao = ExerciseDao(db);
    final count = await exerciseDao.count();
    if (count == 0) {
      await ExerciseLocalService.seedFromAssets(db);
    }

    // One-time migrations — version-gated
    final lastMigration = await secureStorage.read('db_migration_version');
    if (lastMigration != AppConstants.dbMigrationVersion) {
      await ExerciseLocalService.remapMuscleGroups(db);
      await ExerciseLocalService.backfillDifficulty(db);
      await secureStorage.write('db_migration_version', AppConstants.dbMigrationVersion);
    }

    // Seed training programs once
    await ProgramSeeder(db).seedIfNeeded();
  } on Exception catch (e, stack) {
    if (kDebugMode) {
      debugPrint('Background DB init failed: $e');
    } else {
      CrashReporter.recordError(e, stackTrace: stack, reason: 'Background DB init failed');
    }
  }
}
