import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Lightweight crash reporting wrapper.
///
/// In debug builds, logs to the console via [debugPrint].
/// In release builds, forwards non-fatal errors to Firebase Crashlytics
/// so they surface in the production dashboard.
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
  static void recordError(
    Object error, {
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
  }) {
    if (kDebugMode) {
      debugPrint('[CrashReporter] ${reason ?? ''}: $error');
      return;
    }
    _crashlytics?.recordError(
      error,
      stackTrace ?? StackTrace.current,
      reason: reason ?? 'Unspecified',
      fatal: fatal,
    );
  }

  /// Log a breadcrumb message for context in crash reports.
  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[CrashReporter] $message');
      return;
    }
    _crashlytics?.log(message);
  }
}
