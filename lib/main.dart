import 'dart:io';

import 'package:drift/drift.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/daos/exercise_dao.dart';
import 'core/database/daos/session_dao.dart';
import 'core/database/daos/user_profile_dao.dart';
import 'core/providers/providers.dart';
import 'core/security/secure_storage.dart';
import 'core/services/exercise_api_service.dart';
import 'core/services/exercise_repository.dart';
import 'core/services/program_seeder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Firebase — skipped if not yet configured (google-services.json / GoogleService-Info.plist missing)
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase not configured yet — will be set up in Phase 15 (FCM)
  }

  // Supabase — secrets from .env via --dart-define-from-file=.env
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    } catch (_) {
      // Supabase not reachable — app works offline
    }
  }

  // RevenueCat — skipped if keys are placeholders
  final rcKey = Platform.isIOS
      ? const String.fromEnvironment('REVENUECAT_IOS_KEY')
      : const String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  if (rcKey.isNotEmpty && !rcKey.startsWith('your-')) {
    try {
      await Purchases.configure(PurchasesConfiguration(rcKey));
    } catch (_) {
      // RevenueCat not configured yet
    }
  }

  // Database
  final db = AppDatabase.create();

  // WorkoutX API key — injected at build time via --dart-define WORKOUTX_API_KEY.
  const workoutxApiKey = String.fromEnvironment('WORKOUTX_API_KEY');

  // Exercise repository (WorkoutX API + local cache). Exercises are no longer
  // bulk-seeded from a bundled JSON; the seeder only loads a tiny starter set
  // so the default program works offline on first launch.
  final exerciseDao = ExerciseDao(db);
  final exerciseApi = ExerciseApiService(apiKey: workoutxApiKey);
  final exerciseRepo = ExerciseRepository(exerciseApi, exerciseDao);

  // Seed the bundled starter set into the cache (idempotent) so demo sessions
  // and the default program have real exercise data offline.
  final programSeeder = ProgramSeeder(db, exerciseRepo);
  await programSeeder.ensureStarterCached();

  // Seed demo sessions if none exist (for UI preview)
  final sessionDao = SessionDao(db);
  final existingSessions = await sessionDao.getRecent(1);
  if (existingSessions.isEmpty) {
    await _seedDemoSessions(sessionDao, exerciseDao);
  }

  // Seed 3 real training programs if none exist
  await programSeeder.seedIfNeeded();

  // Startup seeding done — release the throwaway HTTP client. The UI uses the
  // repository from `exerciseRepositoryProvider` instead.
  exerciseApi.dispose();

  // Get saved locale preference
  final userProfileDao = UserProfileDao(db);
  final profile = await userProfileDao.getFirst();
  Locale? savedLocale;
  if (profile != null &&
      profile.preferredLanguage != 'system') {
    savedLocale = Locale(profile.preferredLanguage);
  }

  // Get saved theme mode
  final secureStorage = SecureStorage();
  final themeStr = await secureStorage.read('theme_mode');
  ThemeMode? savedTheme;
  if (themeStr == 'ThemeMode.light') {
    savedTheme = ThemeMode.light;
  } else if (themeStr == 'ThemeMode.dark') {
    savedTheme = ThemeMode.dark;
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        workoutxApiKeyProvider.overrideWithValue(workoutxApiKey),
        localeProvider.overrideWith((ref) => savedLocale),
        if (savedTheme != null) themeModeProvider.overrideWith((ref) => savedTheme!),
      ],
      child: const MyGymBroApp(),
    ),
  );
}

/// Seeds 3 demo workout sessions so the sessions log has data to display.
Future<void> _seedDemoSessions(
  SessionDao sessionDao,
  ExerciseDao exerciseDao,
) async {
  final allExercises = await exerciseDao.getAll();
  if (allExercises.isEmpty) return;

  // Pick exercises by muscle group for realistic sessions
  final chestExercises =
      allExercises.where((e) => (e.muscleGroup ?? '').toLowerCase().contains('chest')).take(4).toList();
  final backExercises =
      allExercises.where((e) => (e.muscleGroup ?? '').toLowerCase().contains('back')).take(4).toList();
  final shoulderExercises =
      allExercises.where((e) => (e.muscleGroup ?? '').toLowerCase().contains('shoulder')).take(4).toList();

  // Fallback: if not enough exercises per group, just use first 4
  List<Exercise> pick(List<Exercise> preferred) =>
      preferred.length >= 4 ? preferred : allExercises.take(4).toList();

  final now = DateTime.now();

  // Session 1: Sat, Chest Day — 2 days ago
  final sat = now.subtract(const Duration(days: 2));
  final satStart = DateTime(sat.year, sat.month, sat.day, 23, 30);
  await _insertSession(
    sessionDao,
    startedAt: satStart,
    durationMin: 58,
    exercises: pick(chestExercises),
    baseWeight: 135,
  );

  // Session 2: Thu, Back Day — 4 days ago
  final thu = now.subtract(const Duration(days: 4));
  final thuStart = DateTime(thu.year, thu.month, thu.day, 18, 0);
  await _insertSession(
    sessionDao,
    startedAt: thuStart,
    durationMin: 52,
    exercises: pick(backExercises),
    baseWeight: 120,
  );

  // Session 3: Tue, Shoulder Day — 6 days ago
  final tue = now.subtract(const Duration(days: 6));
  final tueStart = DateTime(tue.year, tue.month, tue.day, 17, 15);
  await _insertSession(
    sessionDao,
    startedAt: tueStart,
    durationMin: 45,
    exercises: pick(shoulderExercises),
    baseWeight: 95,
  );
}

Future<void> _insertSession(
  SessionDao sessionDao, {
  required DateTime startedAt,
  required int durationMin,
  required List<Exercise> exercises,
  required double baseWeight,
}) async {
  final finishedAt = startedAt.add(Duration(minutes: durationMin));
  double totalVol = 0;

  // Create session
  final sessionId = await sessionDao.createSession(SessionsCompanion(
    startedAt: Value(startedAt),
    finishedAt: Value(finishedAt),
    durationSeconds: Value(durationMin * 60),
    createdAt: Value(startedAt),
    updatedAt: Value(finishedAt),
  ));

  // Add exercises with sets
  for (var i = 0; i < exercises.length; i++) {
    final exerciseTime = startedAt.add(Duration(minutes: i * (durationMin ~/ exercises.length)));

    final seId = await sessionDao.addSessionExercise(SessionExercisesCompanion(
      sessionId: Value(sessionId),
      exerciseId: Value(exercises[i].exerciseId),
      orderIndex: Value(i),
      createdAt: Value(exerciseTime),
    ));

    // 3-4 sets per exercise
    final setCount = 3 + (i % 2);
    for (var s = 0; s < setCount; s++) {
      final weight = baseWeight + (i * 10) - (s * 5);
      const reps = 10;
      totalVol += weight * reps;

      await sessionDao.addSet(WorkoutSetsCompanion(
        sessionExerciseId: Value(seId),
        setIndex: Value(s),
        weight: Value(weight),
        reps: Value(reps),
        createdAt: Value(exerciseTime.add(Duration(minutes: s * 2))),
      ));
    }
  }

  // Update session with total volume
  await sessionDao.finishSession(
    sessionId,
    finishedAt,
    durationMin * 60,
    totalVol,
  );
}


