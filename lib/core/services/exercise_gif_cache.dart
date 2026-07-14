import 'package:cached_network_image/cached_network_image.dart' show CachedNetworkImage;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Bounded on-device cache for exercise GIFs.
///
/// Exercise GIFs are large (~1 MB+ each, animated). `cached_network_image`'s
/// default manager keeps up to 200 files with a 30-day stale window, which —
/// once you scroll the online catalogue — balloons the app's cache to 250 MB+.
///
/// This shared manager caps the GIF cache so it stays modest while still
/// comfortably covering a user's saved program + recently viewed exercises for
/// offline use. ALL exercise-GIF [CachedNetworkImage]s and the notification
/// image cache use this instance so they share one bounded store.
class ExerciseGifCache {
  ExerciseGifCache._();

  // Renamed from 'workoutxGifCache' on the ExerciseDB switch — the fresh box
  // abandons stale WorkoutX GIFs (their auth'd URLs are dead without a key).
  static const String key = 'exerciseGifCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      // ~80 GIFs ≈ a generous program + recents; well under the old 200.
      maxNrOfCacheObjects: 80,
      stalePeriod: const Duration(days: 14),
    ),
  );
}
