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
      expect(head(1999), l10n.shareHeavierThan(l10n.shareVolumeCar));
      expect(head(2000), l10n.shareHeavierThan(l10n.shareVolumeSuv));
      expect(head(2999), l10n.shareHeavierThan(l10n.shareVolumeSuv));
      expect(head(3000), l10n.shareHeavierThan(l10n.shareVolumeVan));
      expect(head(5999), l10n.shareHeavierThan(l10n.shareVolumeVan));
      expect(head(6000), l10n.shareHeavierThan(l10n.shareVolumeElephant));
      expect(head(7999), l10n.shareHeavierThan(l10n.shareVolumeElephant));
      expect(head(8000), l10n.shareHeavierThan(l10n.shareVolumeTRex));
      expect(head(12000), l10n.shareHeavierThan(l10n.shareVolumeTwoElephants));
      expect(head(20000), l10n.shareHeavierThan(l10n.shareVolumeExcavator));
      expect(head(30000), l10n.shareHeavierThan(l10n.shareVolumeHumpbackWhale));
      expect(head(78000), l10n.shareHeavierThan(l10n.shareVolumeSpaceShuttle));
      expect(head(150000), l10n.shareHeavierThan(l10n.shareVolumeBlueWhale));
    });

    test('typical session volumes no longer all read "elephant"', () {
      final objects = {
        for (final kg in [4000.0, 7826.0, 9500.0, 14000.0, 25000.0])
          volumeComparison(kg, l10n).objectLabel,
      };
      expect(objects, hasLength(5));
    });
    test('below the lightest object falls back to the neutral caption', () {
      final c = volumeComparison(10, l10n);
      expect(c.headline, l10n.shareVolumeCaption);
      expect(c.objectLabel, l10n.shareObjectDog);
      expect(c.objectKg, 30);
    });
    test('legend carries the object label and canonical kg', () {
      final c = volumeComparison(9000, l10n);
      expect(c.objectLabel, l10n.shareObjectTRex);
      expect(c.objectKg, 8000);
    });
  });
}
