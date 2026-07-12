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

/// Maps a total lifted volume (in kg) to a fun, relatable object comparison.
/// Tiers are keyed off the canonical kg figure so the object is stable
/// regardless of the user's display unit. Returns a tier-specific `headline`
/// (the object) plus a shared motivational `subline`.
({String headline, String subline}) volumeComparison(
  double kg,
  AppLocalizations l10n,
) {
  final subline = l10n.shareVolumeCaption;
  if (kg >= 6000) return (headline: l10n.shareVolumeElephant, subline: subline);
  if (kg >= 3000) return (headline: l10n.shareVolumeVan, subline: subline);
  if (kg >= 1200) return (headline: l10n.shareVolumeCar, subline: subline);
  if (kg >= 450) return (headline: l10n.shareVolumePiano, subline: subline);
  if (kg >= 150) return (headline: l10n.shareVolumeFridge, subline: subline);
  return (headline: l10n.shareVolumeDog, subline: subline);
}
