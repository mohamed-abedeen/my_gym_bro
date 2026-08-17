import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';

/// Which lens the anatomy body shows: recovery state or training volume.
enum AnatomyViewMode { recovery, volume }

/// Selectable window for the volume lens.
enum VolumeWindow { thisWeek, fourWeeks }

/// Weekly-set buckets against the evidence-based hypertrophy guideline of
/// ~10–20 weighted working sets per muscle per week (same guideline the
/// weekly radar in the status sheet uses).
enum VolumeLevel { none, low, optimal, high }

/// Lower/upper bound of the optimal weekly-sets band.
const double volumeTargetLow = 10;
const double volumeTargetHigh = 20;

/// Weekly sets at which the over-target ramp reaches full danger red.
const double volumeOverRampEnd = 30;

VolumeLevel volumeLevelFor(double weeklySets) {
  if (weeklySets <= 0) return VolumeLevel.none;
  if (weeklySets < volumeTargetLow) return VolumeLevel.low;
  if (weeklySets <= volumeTargetHigh) return VolumeLevel.optimal;
  return VolumeLevel.high;
}

/// Continuous colour scale for the volume lens: grey when untrained, an
/// amber → green ramp while under target, solid green inside the 10–20 band,
/// then green → red as volume overshoots toward [volumeOverRampEnd].
///
/// Deliberately reuses the recovery view's semantic colours (green = good)
/// so the body reads consistently across both lenses.
Color volumeColorFor(double weeklySets) {
  if (weeklySets <= 0) return AppColors.muscleUntrained;
  if (weeklySets < volumeTargetLow) {
    return Color.lerp(
      AppColors.amber,
      AppColors.success,
      weeklySets / volumeTargetLow,
    )!;
  }
  if (weeklySets <= volumeTargetHigh) return AppColors.success;
  final t = ((weeklySets - volumeTargetHigh) /
          (volumeOverRampEnd - volumeTargetHigh))
      .clamp(0.0, 1.0);
  return Color.lerp(AppColors.success, AppColors.danger, t)!;
}

/// Training volume for one muscle group over the selected window.
class MuscleVolumeInfo {
  const MuscleVolumeInfo({
    required this.muscleGroup,
    required this.setsInWindow,
    required this.weeklySets,
  });

  final String muscleGroup;

  /// Raw weighted working sets inside the window (primary ×1.0,
  /// secondary ×0.5 — the recovery dose model's credit).
  final double setsInWindow;

  /// Weekly-equivalent sets (raw ÷ weeks in the window) — the value compared
  /// against the 10–20 guideline so every window uses the same scale.
  final double weeklySets;

  VolumeLevel get level => volumeLevelFor(weeklySets);
  Color get color => volumeColorFor(weeklySets);
}

/// One entry per canonical muscle group — groups absent from [totals] get 0.
/// Cardio is excluded (no anatomy overlay, mirroring the recovery sheet).
List<MuscleVolumeInfo> buildMuscleVolumeInfos({
  required Map<String, double> totals,
  required List<String> allGroups,
  required int weeksInWindow,
}) {
  return [
    for (final group in allGroups)
      if (group != 'Cardio')
        MuscleVolumeInfo(
          muscleGroup: group,
          setsInWindow: totals[group] ?? 0,
          weeklySets: (totals[group] ?? 0) / weeksInWindow,
        ),
  ];
}

/// "7.5" / "12" — at most one decimal, trailing .0 trimmed. Secondary-muscle
/// credit is 0.5, so halves are the only fractions that occur in practice.
String formatWeightedSets(double sets) {
  final rounded = (sets * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1);
}
