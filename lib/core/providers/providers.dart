import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/auth/auth_notifier.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/sync_service.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
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
