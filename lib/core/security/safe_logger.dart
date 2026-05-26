import 'package:flutter/foundation.dart';

/// Debug-only logger that redacts sensitive values.
class SafeLogger {
  SafeLogger._();

  static const _sensitivePatterns = [
    'password',
    'token',
    'key',
    'email',
    'jwt',
    'secret',
    'auth',
    'receipt',
    'credential',
    'cookie',
    'session_id',
  ];

  /// Log a message — only in debug mode. Redacts sensitive key-value pairs.
  static void log(String message, {String? tag}) {
    if (!kDebugMode) return;

    var safe = message;
    for (final pattern in _sensitivePatterns) {
      // Redact patterns like: "token": "abc123" or token=abc123
      safe = safe.replaceAll(
        RegExp('("$pattern"\\s*:\\s*)"[^"]*"', caseSensitive: false),
        r'$1"[REDACTED]"',
      );
      safe = safe.replaceAll(
        RegExp('$pattern=\\S+', caseSensitive: false),
        '$pattern=[REDACTED]',
      );
    }

    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('$prefix$safe');
  }
}
