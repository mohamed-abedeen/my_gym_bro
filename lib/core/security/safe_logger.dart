import 'package:flutter/foundation.dart';

/// Debug-only logger and shared PII scrubber.
///
/// The [scrub] helper is also used by `CrashReporter` so anything that
/// reaches Crashlytics passes through the same redaction pipeline.
class SafeLogger {
  SafeLogger._();

  // ── Key=value / JSON patterns ─────────────────────────────────────────
  static const _sensitiveKeys = [
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
    'access_token',
    'refresh_token',
    'id_token',
    'apikey',
    'api_key',
  ];

  // ── Free-floating PII patterns ────────────────────────────────────────
  // Order matters: redact the longest/most-specific things first so
  // shorter patterns don't chew into them.

  /// JWT (three base64url segments separated by `.`). Caught before bare
  /// UUIDs because the middle segment can look like base64-padded text.
  static final _jwtRx = RegExp(
    r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+',
  );

  /// Standard UUID v1–v5.
  static final _uuidRx = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  /// Conservative email regex — good enough for log scrubbing, not for
  /// validation. RFC 5322 is intentionally out of scope.
  static final _emailRx = RegExp(
    r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
  );

  /// Bearer tokens in Authorization headers.
  static final _bearerRx = RegExp(
    r'[Bb]earer\s+[A-Za-z0-9._\-]+',
  );

  /// Returns a copy of [input] with sensitive values redacted. Safe to
  /// run on any user-provided or system-provided string; never throws.
  ///
  /// Used by both [log] (debug) and [CrashReporter] (release), so the
  /// redaction set is shared.
  static String scrub(String input) {
    var s = input;

    // 1. JWTs and bearer tokens first (they may contain dots that would
    //    otherwise be misread by later patterns).
    s = s.replaceAll(_jwtRx, '[jwt]');
    s = s.replaceAll(_bearerRx, 'Bearer [redacted]');

    // 2. Emails before UUIDs (an email local-part can look UUID-ish).
    s = s.replaceAll(_emailRx, '[email]');

    // 3. UUIDs (user IDs, session IDs, Supabase row IDs).
    s = s.replaceAll(_uuidRx, '[uuid]');

    // 4. Key-value pairs (JSON + query-string forms).
    for (final key in _sensitiveKeys) {
      s = s.replaceAll(
        RegExp('("$key"\\s*:\\s*)"[^"]*"', caseSensitive: false),
        r'$1"[redacted]"',
      );
      s = s.replaceAll(
        RegExp('$key=\\S+', caseSensitive: false),
        '$key=[redacted]',
      );
    }

    return s;
  }

  /// Log a message — only in debug mode. Redacts sensitive values.
  static void log(String message, {String? tag}) {
    if (!kDebugMode) return;
    final prefix = tag != null ? '[$tag] ' : '';
    debugPrint('$prefix${scrub(message)}');
  }
}
