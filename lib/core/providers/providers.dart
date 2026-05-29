import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/widgets/anatomy_body.dart';
import '../auth/auth_notifier.dart';
import '../database/app_database.dart';
import '../database/daos/exercise_dao.dart';
import '../services/exercise_api_service.dart';
import '../services/exercise_repository.dart';
import '../services/sync_service.dart';

/// Global database provider — overridden at app startup with the real instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden at startup');
});

/// Global locale provider — overridden at app startup if the user has a saved language.
final localeProvider = StateProvider<Locale?>((ref) => null);

/// Theme mode provider — defaults to dark.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// Supabase client provider — returns null if Supabase wasn't initialized.
final supabaseProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

/// WorkoutX API key — overridden at startup from `--dart-define WORKOUTX_API_KEY`.
/// Empty string means no key configured (network exercise features disabled).
final workoutxApiKeyProvider = Provider<String>((ref) => '');

/// WorkoutX exercise API client.
final exerciseApiServiceProvider = Provider<ExerciseApiService>((ref) {
  final apiKey = ref.watch(workoutxApiKeyProvider);
  final service = ExerciseApiService(apiKey: apiKey);
  ref.onDispose(service.dispose);
  return service;
});

/// Exercise repository: WorkoutX API + local Drift cache (offline-first).
final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final api = ref.watch(exerciseApiServiceProvider);
  final dao = ExerciseDao(ref.watch(databaseProvider));
  return ExerciseRepository(api, dao);
});

/// Sync service provider.
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  final supabase = ref.watch(supabaseProvider);
  return SyncService(db, supabase);
});

/// Auth notifier provider.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final db = ref.watch(databaseProvider);
  final supabase = ref.watch(supabaseProvider);
  final syncService = ref.watch(syncServiceProvider);
  return AuthNotifier(db, supabase, syncService);
});

/// Whether Supabase is available (initialized).
final isSupabaseAvailableProvider = Provider<bool>((ref) {
  return ref.watch(supabaseProvider) != null;
});

final anatomyGenderProvider = StateProvider<AnatomyGender>((ref) => AnatomyGender.male);
