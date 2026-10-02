import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/core/services/program_seeder.dart';

/// Readies the device for entering the app: clears the one-off exercise-seed
/// flag and caches the tiny bundled starter set so the default program has
/// rich data offline. Startup does the caching too, but may not have finished
/// yet. Used after sign-up and by the dev/beta Skips (sign-up, Sign In).
Future<void> prepareAppEntry(WidgetRef ref) async {
  await SecureStorage().delete('needs_exercise_seed');
  try {
    await ProgramSeeder(
      ref.read(databaseProvider),
      ref.read(exerciseRepositoryProvider),
    ).ensureStarterCached();
  } on Exception {
    // Non-fatal — proceed regardless.
  }
}
