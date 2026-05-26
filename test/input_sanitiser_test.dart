import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/security/input_sanitiser.dart';

void main() {
  group('InputSanitiser.sanitise', () {
    test('returns input unchanged when clean', () {
      expect(InputSanitiser.sanitise('Hello World'), 'Hello World');
    });

    test('strips HTML tags', () {
      expect(InputSanitiser.sanitise('<b>Bold</b>'), 'Bold');
      expect(InputSanitiser.sanitise('<script>alert("x")</script>text'), 'text');
    });

    test('strips control characters but preserves newlines and tabs', () {
      // \x07 is BEL (control char), should be stripped
      expect(InputSanitiser.sanitise('hello\x07world'), 'hello world');
      // newline and tab should survive
      expect(InputSanitiser.sanitise('line1\nline2'), 'line1\nline2');
      expect(InputSanitiser.sanitise('col1\tcol2'), 'col1\tcol2');
    });

    test('trims leading and trailing whitespace', () {
      expect(InputSanitiser.sanitise('  hello  '), 'hello');
    });

    test('truncates to default 500 characters', () {
      final long = 'a' * 600;
      expect(InputSanitiser.sanitise(long).length, 500);
    });

    test('truncates to custom maxLength', () {
      expect(InputSanitiser.sanitise('hello world', maxLength: 5), 'hello');
    });

    test('handles empty string', () {
      expect(InputSanitiser.sanitise(''), '');
    });

    test('handles string with only HTML', () {
      expect(InputSanitiser.sanitise('<div><p></p></div>'), '');
    });
  });

  group('InputSanitiser.parseWeight', () {
    test('parses valid decimal weight', () {
      expect(InputSanitiser.parseWeight('100.5'), 100.5);
    });

    test('parses integer weight', () {
      expect(InputSanitiser.parseWeight('80'), 80.0);
    });

    test('strips non-numeric characters', () {
      expect(InputSanitiser.parseWeight('75kg'), 75.0);
    });

    test('returns null for empty string', () {
      expect(InputSanitiser.parseWeight(''), isNull);
    });

    test('returns null for non-numeric input', () {
      expect(InputSanitiser.parseWeight('abc'), isNull);
    });

    test('returns null for negative value', () {
      expect(InputSanitiser.parseWeight('-10'), isNull);
    });

    test('returns null for value above 9999', () {
      expect(InputSanitiser.parseWeight('10000'), isNull);
    });

    test('accepts boundary value 9999', () {
      expect(InputSanitiser.parseWeight('9999'), 9999.0);
    });
  });

  group('InputSanitiser.parseReps', () {
    test('parses valid integer reps', () {
      expect(InputSanitiser.parseReps('12'), 12);
    });

    test('strips non-numeric characters', () {
      expect(InputSanitiser.parseReps('10 reps'), 10);
    });

    test('returns null for empty string', () {
      expect(InputSanitiser.parseReps(''), isNull);
    });

    test('returns null for non-numeric input', () {
      expect(InputSanitiser.parseReps('many'), isNull);
    });

    test('returns null for value above 9999', () {
      expect(InputSanitiser.parseReps('10000'), isNull);
    });

    test('accepts boundary value 9999', () {
      expect(InputSanitiser.parseReps('9999'), 9999);
    });

    test('returns null for negative value', () {
      expect(InputSanitiser.parseReps('-5'), isNull);
    });
  });
}
