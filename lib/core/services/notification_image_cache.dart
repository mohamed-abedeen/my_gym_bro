import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';

/// Resolves a remote image URL (exercise GIF, profile avatar, etc.) into a
/// **local file path** suitable for `FilePathAndroidBitmap` in
/// `flutter_local_notifications`.
///
/// * Re-uses the same on-device cache that `cached_network_image` writes to,
///   so a thumbnail the user already saw in-app is instant here.
/// * Times out aggressively — a notification that takes 5 s to render its
///   art is worse than one that ships with no art at all.
/// * Returns `null` (silent) on any error so the caller can fall back to a
///   plain-text notification.
class NotificationImageCache {
  NotificationImageCache._();

  static const _timeout = Duration(seconds: 2);

  /// Returns a local file path for [url], or null if it can't be resolved
  /// in [_timeout] for any reason.
  static Future<String?> filePathFor(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final file = await ExerciseGifCache.instance
          .getSingleFile(url)
          .timeout(_timeout);
      if (!await File(file.path).exists()) return null;
      return file.path;
    } on TimeoutException {
      return null;
    } on Object catch (e) {
      // Cache-manager throws plain Exceptions, HttpExceptions, FileSystem
      // errors etc. — silence them all; this is best-effort.
      if (kDebugMode) {
        debugPrint('[NotificationImageCache] $url failed: $e');
      }
      return null;
    }
  }
}
