import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Names a workout from the muscle groups it worked: the most-trained group
/// becomes `Chest Day`, falling back to `Workout` when there are none.
///
/// Duplicated (intentionally) from the session-enrichment isolate in
/// `workout_providers.dart` so the share feature can name a workout without
/// pulling in that isolate. Keep the two in sync if the naming rule changes.
String deriveWorkoutName(Iterable<String?> muscleGroups) {
  final counts = <String, int>{};
  for (final mg in muscleGroups) {
    final group = mg ?? 'General';
    counts[group] = (counts[group] ?? 0) + 1;
  }
  if (counts.isEmpty) return 'Workout';
  final top =
      counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return '$top Day';
}

/// Formats a duration as "Xh Ym" (or "Ym" under an hour). Mirrors
/// `WeeklyStats.formattedDuration`.
String formatShareDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

/// Maps a total lifted volume (in kg) to a relatable object comparison for
/// the Hype card: a `headline` ("Heavier than a full-grown elephant."), the
/// short `objectLabel` for the scale legend ("ELEPHANT"), and the object's
/// canonical `objectKg` (drives the bar fill/marker). Tiers are keyed off the
/// canonical kg figure so the object is stable regardless of display unit.
///
/// Picks the heaviest object the user out-lifted. Below the lightest object
/// (30 kg) the "heavier than" claim would be false, so the headline falls
/// back to the neutral caption and the bar shows partial progress to the dog.
///
/// The ladder runs well past a typical session (5,000–20,000 kg) so the
/// object changes with the workout — it used to stop at the elephant, so
/// nearly every real session read "Heavier than a full-grown elephant".
/// Weights are conservative so the "heavier than" claim holds at each step.
({String headline, String objectLabel, double objectKg}) volumeComparison(
  double kg,
  AppLocalizations l10n,
) {
  final tiers = <({double kg, String phrase, String label})>[
    (kg: 150000, phrase: l10n.shareVolumeBlueWhale, label: l10n.shareObjectBlueWhale),
    (kg: 78000, phrase: l10n.shareVolumeSpaceShuttle, label: l10n.shareObjectSpaceShuttle),
    (kg: 30000, phrase: l10n.shareVolumeHumpbackWhale, label: l10n.shareObjectHumpbackWhale),
    (kg: 20000, phrase: l10n.shareVolumeExcavator, label: l10n.shareObjectExcavator),
    (kg: 12000, phrase: l10n.shareVolumeTwoElephants, label: l10n.shareObjectTwoElephants),
    (kg: 8000, phrase: l10n.shareVolumeTRex, label: l10n.shareObjectTRex),
    (kg: 6000, phrase: l10n.shareVolumeElephant, label: l10n.shareObjectElephant),
    (kg: 3000, phrase: l10n.shareVolumeVan, label: l10n.shareObjectVan),
    (kg: 2000, phrase: l10n.shareVolumeSuv, label: l10n.shareObjectSuv),
    (kg: 1200, phrase: l10n.shareVolumeCar, label: l10n.shareObjectCar),
    (kg: 450, phrase: l10n.shareVolumePiano, label: l10n.shareObjectPiano),
    (kg: 150, phrase: l10n.shareVolumeFridge, label: l10n.shareObjectFridge),
    (kg: 30, phrase: l10n.shareVolumeDog, label: l10n.shareObjectDog),
  ];
  for (final t in tiers) {
    if (kg >= t.kg) {
      return (
        headline: l10n.shareHeavierThan(t.phrase),
        objectLabel: t.label,
        objectKg: t.kg,
      );
    }
  }
  return (
    headline: l10n.shareVolumeCaption,
    objectLabel: l10n.shareObjectDog,
    objectKg: 30,
  );
}
