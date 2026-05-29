import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lock-screen Live Activity controller (iOS 16.1+).
///
/// Best-effort by design: every method swallows errors and returns either
/// `null`, `false`, or void so a missing entitlement, an Android device,
/// or a user who has disabled Live Activities in Settings never breaks the
/// workout flow. The caller pretends it's not there if it doesn't work.
///
/// Android equivalent (persistent ongoing notification) is already handled
/// by `NotificationService.showActiveWorkout` — this service is a no-op on
/// non-iOS platforms.
class LiveActivityService {
  LiveActivityService._();

  static const _channel = MethodChannel('com.mygymbro/live_activity');

  /// True only when the platform can actually show a Live Activity AND the
  /// user has them enabled in iOS Settings. Cached after first check.
  static bool? _supportedCache;

  static Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    if (_supportedCache != null) return _supportedCache!;
    try {
      final ok = await _channel.invokeMethod<bool>('isSupported');
      _supportedCache = ok ?? false;
      return _supportedCache!;
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] isSupported failed: ${e.message}');
      _supportedCache = false;
      return false;
    } on MissingPluginException {
      // Bridge isn't registered (e.g. running on the simulator with the
      // widget target not yet added). Treat as unsupported.
      _supportedCache = false;
      return false;
    }
  }

  /// Begin a new workout activity. Returns the platform-provided activity
  /// id on success, null on failure or unsupported platform.
  static Future<String?> start({
    required String exerciseName,
    required String setProgress,
    required DateTime sessionStartedAt,
  }) async {
    if (!await isSupported()) return null;
    try {
      return await _channel.invokeMethod<String>('start', {
        'exerciseName': exerciseName,
        'setProgress': setProgress,
        'sessionStartedAtMillis': sessionStartedAt.millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] start failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Switch the activity to "resting" mode with a countdown that expires at
  /// [restEndsAt]. The lock-screen UI ticks on-device from this date — no
  /// need to push every second.
  static Future<void> updateRest({
    required String exerciseName,
    required String setProgress,
    required DateTime restEndsAt,
  }) async {
    if (!await isSupported()) return;
    try {
      await _channel.invokeMethod<bool>('updateRest', {
        'exerciseName': exerciseName,
        'setProgress': setProgress,
        'restEndsAtMillis': restEndsAt.millisecondsSinceEpoch,
      });
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] updateRest failed: ${e.message}');
    } on MissingPluginException {
      /* no-op */
    }
  }

  /// Switch the activity back to "active set" mode (no countdown).
  static Future<void> updateActive({
    required String exerciseName,
    required String setProgress,
  }) async {
    if (!await isSupported()) return;
    try {
      await _channel.invokeMethod<bool>('updateActive', {
        'exerciseName': exerciseName,
        'setProgress': setProgress,
      });
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] updateActive failed: ${e.message}');
    } on MissingPluginException {
      /* no-op */
    }
  }

  /// Dismiss the activity. Safe to call repeatedly.
  static Future<void> end() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('end');
    } on PlatformException catch (e) {
      debugPrint('[LiveActivity] end failed: ${e.message}');
    } on MissingPluginException {
      /* no-op */
    }
  }
}
