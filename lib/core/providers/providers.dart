import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/auth/auth_notifier.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/core/services/exercise_api_service.dart';
import 'package:my_gym_bro/core/services/exercise_repository.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  } catch (_) { // ignore: avoid_catches_without_on_clauses
    // Catches both Exception and AssertionError (thrown when Supabase is
    // not initialised — AssertionError is an Error, not an Exception).
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

/// Anatomy-body gender toggle. Persisted via SecureStorage so the choice
/// survives app restarts (it used to silently reset to male).
class AnatomyGenderNotifier extends StateNotifier<AnatomyGender> {
  AnatomyGenderNotifier() : super(AnatomyGender.male) {
    _load();
  }

  static const _key = 'setting_anatomy_gender';

  Future<void> _load() async {
    final raw = await SecureStorage().read(_key);
    if (raw == 'female' && mounted) state = AnatomyGender.female;
  }

  Future<void> set(AnatomyGender gender) async {
    state = gender;
    await SecureStorage()
        .write(_key, gender == AnatomyGender.female ? 'female' : 'male');
  }
}

final anatomyGenderProvider =
    StateNotifierProvider<AnatomyGenderNotifier, AnatomyGender>(
  (ref) => AnatomyGenderNotifier(),
);

/// Reads the bundled app version + build number once at startup. Cached
/// after the first read, so it's safe to watch from any screen footer.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});
