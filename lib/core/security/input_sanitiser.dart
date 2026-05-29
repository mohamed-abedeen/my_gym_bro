/// Sanitises all user text input before DB writes or API calls.
class InputSanitiser {
  InputSanitiser._();

  // ── Static patterns (compiled once) ───────────────────────────────────
  // Block-level tags whose *contents* must be stripped, not just the
  // wrapping tag — otherwise an attacker can sneak a payload through.
  static final _scriptBlockRx = RegExp(
    r'<script\b[^>]*>[\s\S]*?</script>',
    caseSensitive: false,
  );
  static final _styleBlockRx = RegExp(
    r'<style\b[^>]*>[\s\S]*?</style>',
    caseSensitive: false,
  );
  static final _tagRx = RegExp('<[^>]*>');
  static final _controlCharRx =
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  /// Strip control characters, HTML tags, trim, and truncate.
  ///
  /// Control characters are replaced with a single space (rather than
  /// removed) so that adjacent words don't fuse together — making the
  /// result safer to display and easier to read.
  static String sanitise(String input, {int maxLength = 500}) {
    var result = input;

    // 1. Remove dangerous block elements WITH their inner content.
    result = result.replaceAll(_scriptBlockRx, '');
    result = result.replaceAll(_styleBlockRx, '');

    // 2. Strip remaining standalone HTML tags (leaving inner text).
    result = result.replaceAll(_tagRx, '');

    // 3. Replace control characters with a space so words stay separated.
    //    Newlines and tabs are intentionally preserved.
    result = result.replaceAll(_controlCharRx, ' ');

    // 4. Trim and truncate.
    result = result.trim();
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    return result;
  }

  /// Parse a weight string to double (kg or lbs).
  /// Returns null if unparseable, negative, or out of range.
  static double? parseWeight(String input) {
    if (_isNegative(input)) return null;
    final cleaned = input.replaceAll(RegExp('[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value < 0 || value > 9999) return null;
    return value;
  }

  /// Parse a reps string to int.
  /// Returns null if unparseable, negative, or out of range.
  static int? parseReps(String input) {
    if (_isNegative(input)) return null;
    final cleaned = input.replaceAll(RegExp('[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    final value = int.tryParse(cleaned);
    if (value == null || value < 0 || value > 9999) return null;
    return value;
  }

  /// Detect a leading minus sign BEFORE the non-numeric scrubber would
  /// strip it (which would otherwise turn `-10` into a valid `10`).
  static bool _isNegative(String input) {
    final trimmed = input.trimLeft();
    return trimmed.startsWith('-');
  }
}
