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
    test('boundaries pick the heaviest out-lifted object', () {
      expect(head(30), l10n.shareHeavierThan(l10n.shareVolumeDog));
      expect(head(149), l10n.shareHeavierThan(l10n.shareVolumeDog));
      expect(head(150), l10n.shareHeavierThan(l10n.shareVolumeFridge));
      expect(head(449), l10n.shareHeavierThan(l10n.shareVolumeFridge));
      expect(head(450), l10n.shareHeavierThan(l10n.shareVolumePiano));
      expect(head(1199), l10n.shareHeavierThan(l10n.shareVolumePiano));
      expect(head(1200), l10n.shareHeavierThan(l10n.shareVolumeCar));
      expect(head(2999), l10n.shareHeavierThan(l10n.shareVolumeCar));
      expect(head(3000), l10n.shareHeavierThan(l10n.shareVolumeVan));
      expect(head(5999), l10n.shareHeavierThan(l10n.shareVolumeVan));
      expect(head(6000), l10n.shareHeavierThan(l10n.shareVolumeElephant));
    });
    test('below the lightest object falls back to the neutral caption', () {
      final c = volumeComparison(10, l10n);
      expect(c.headline, l10n.shareVolumeCaption);
      expect(c.objectLabel, l10n.shareObjectDog);
      expect(c.objectKg, 30);
    });
    test('legend carries the object label and canonical kg', () {
      final c = volumeComparison(9000, l10n);
      expect(c.objectLabel, l10n.shareObjectElephant);
      expect(c.objectKg, 6000);
    });
  });
}
