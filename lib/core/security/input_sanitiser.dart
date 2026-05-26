/// Sanitises all user text input before DB writes or API calls.
class InputSanitiser {
  InputSanitiser._();

  /// Strip control characters, HTML tags, trim, and truncate.
  static String sanitise(String input, {int maxLength = 500}) {
    var result = input;

    // Strip HTML tags
    result = result.replaceAll(RegExp('<[^>]*>'), '');

    // Strip control characters (keep newlines and tabs)
    result = result.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Trim whitespace
    result = result.trim();

    // Truncate to max length
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    return result;
  }

  /// Parse a weight string to double (kg or lbs).
  /// Returns null if unparseable.
  static double? parseWeight(String input) {
    final cleaned = input.replaceAll(RegExp('[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || value < 0 || value > 9999) return null;
    return value;
  }

  /// Parse a reps string to int.
  /// Returns null if unparseable.
  static int? parseReps(String input) {
    final cleaned = input.replaceAll(RegExp('[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    final value = int.tryParse(cleaned);
    if (value == null || value < 0 || value > 9999) return null;
    return value;
  }
}
