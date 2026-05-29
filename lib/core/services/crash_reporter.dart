import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:my_gym_bro/core/security/safe_logger.dart';

/// Lightweight crash reporting wrapper.
///
/// In debug builds, logs to the console via [debugPrint].
/// In release builds, forwards non-fatal errors to Firebase Crashlytics
/// so they surface in the production dashboard.
///
/// Every string that reaches Crashlytics passes through [SafeLogger.scrub]
/// so emails, UUIDs, JWTs, bearer tokens, and key=value sensitive fields
/// never leak off-device.
class CrashReporter {
  CrashReporter._();

  // Lazy getter — returns null if Firebase was never initialized.
  static FirebaseCrashlytics? get _crashlytics {
    try {
      return FirebaseCrashlytics.instance;
    } catch (_) {
      return null;
    }
  }

  /// Record a non-fatal error with optional context.
  ///
  /// The error's `toString()` and the optional [reason] are both scrubbed
  /// before being sent to Crashlytics. The original [error] object is
  /// wrapped in a [_ScrubbedError] so the stack trace stays useful but
  /// the printed message is safe.
  static void recordError(
    Object error, {
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
  }) {
    final safeReason = reason == null ? null : SafeLogger.scrub(reason);
    final safeError = _ScrubbedError(SafeLogger.scrub(error.toString()));

    if (kDebugMode) {
      debugPrint('[CrashReporter] ${safeReason ?? ''}: $safeError');
      return;
    }
    _crashlytics?.recordError(
      safeError,
      stackTrace ?? StackTrace.current,
      reason: safeReason ?? 'Unspecified',
      fatal: fatal,
    );
  }

  /// Log a breadcrumb message for context in crash reports. Scrubbed.
  static void log(String message) {
    final safe = SafeLogger.scrub(message);
    if (kDebugMode) {
      debugPrint('[CrashReporter] $safe');
      return;
    }
    _crashlytics?.log(safe);
  }
}

/// Wraps a pre-scrubbed message so its `toString()` is what Crashlytics
/// displays — without us having to construct a synthetic Exception.
class _ScrubbedError implements Exception {
  _ScrubbedError(this.message);
  final String message;

  @override
  String toString() => message;
}
