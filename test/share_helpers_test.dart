import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/features/workout/share/share_helpers.dart';
import 'package:my_gym_bro/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('deriveWorkoutName', () {
    test('empty -> Workout', () {
      expect(deriveWorkoutName(const []), 'Workout');
    });
    test('most-trained group wins', () {
      expect(
        deriveWorkoutName(const ['Chest', 'Chest', 'Triceps']),
        'Chest Day',
      );
    });
    test('null maps to General', () {
      expect(deriveWorkoutName(const [null]), 'General Day');
    });
  });

  group('formatShareDuration', () {
    test('under an hour', () => expect(formatShareDuration(90), '1m'));
    test('zero', () => expect(formatShareDuration(0), '0m'));
    test('over an hour', () => expect(formatShareDuration(3661), '1h 1m'));
  });

  group('volumeComparison tiers', () {
    String head(double kg) => volumeComparison(kg, l10n).headline;
    test('boundaries pick the right object', () {
      expect(head(0), l10n.shareVolumeDog);
      expect(head(149), l10n.shareVolumeDog);
      expect(head(150), l10n.shareVolumeFridge);
      expect(head(449), l10n.shareVolumeFridge);
      expect(head(450), l10n.shareVolumePiano);
      expect(head(1199), l10n.shareVolumePiano);
      expect(head(1200), l10n.shareVolumeCar);
      expect(head(2999), l10n.shareVolumeCar);
      expect(head(3000), l10n.shareVolumeVan);
      expect(head(5999), l10n.shareVolumeVan);
      expect(head(6000), l10n.shareVolumeElephant);
    });
    test('subline is shared across tiers', () {
      expect(volumeComparison(10, l10n).subline, l10n.shareVolumeCaption);
      expect(volumeComparison(9000, l10n).subline, l10n.shareVolumeCaption);
    });
  });
}
