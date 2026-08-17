import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/muscle_volume.dart';
import 'package:my_gym_bro/shared/constants.dart';

void main() {
  group('volumeLevelFor', () {
    test('0 sets is untrained', () {
      expect(volumeLevelFor(0), VolumeLevel.none);
    });

    test('below 10 weekly sets is low', () {
      expect(volumeLevelFor(0.5), VolumeLevel.low);
      expect(volumeLevelFor(9.99), VolumeLevel.low);
    });

    test('10–20 weekly sets is optimal (inclusive bounds)', () {
      expect(volumeLevelFor(10), VolumeLevel.optimal);
      expect(volumeLevelFor(15), VolumeLevel.optimal);
      expect(volumeLevelFor(20), VolumeLevel.optimal);
    });

    test('above 20 weekly sets is high', () {
      expect(volumeLevelFor(20.5), VolumeLevel.high);
      expect(volumeLevelFor(40), VolumeLevel.high);
    });
  });

  group('volumeColorFor', () {
    test('untrained is grey', () {
      expect(volumeColorFor(0), AppColors.muscleUntrained);
    });

    test('under-target ramps amber → green', () {
      expect(
        volumeColorFor(5),
        Color.lerp(AppColors.amber, AppColors.success, 0.5),
      );
    });

    test('optimal band is solid green', () {
      expect(volumeColorFor(10), AppColors.success);
      expect(volumeColorFor(15), AppColors.success);
      expect(volumeColorFor(20), AppColors.success);
    });

    test('over-target ramps green → red, saturating at the ramp end', () {
      expect(
        volumeColorFor(25),
        Color.lerp(AppColors.success, AppColors.danger, 0.5),
      );
      expect(volumeColorFor(volumeOverRampEnd), AppColors.danger);
      expect(volumeColorFor(50), AppColors.danger);
    });
  });

  group('buildMuscleVolumeInfos', () {
    test('covers every canonical group except Cardio, zero-filling gaps', () {
      final infos = buildMuscleVolumeInfos(
        totals: {'Chest': 12.0, 'Cardio': 3.0},
        allGroups: MuscleRecoveryService.allMuscleGroups,
        weeksInWindow: 1,
      );

      expect(
        infos.map((i) => i.muscleGroup),
        isNot(contains('Cardio')),
      );
      expect(
        infos.length,
        MuscleRecoveryService.allMuscleGroups.length - 1,
      );

      final chest = infos.singleWhere((i) => i.muscleGroup == 'Chest');
      expect(chest.setsInWindow, 12.0);
      expect(chest.weeklySets, 12.0);
      expect(chest.level, VolumeLevel.optimal);

      final biceps = infos.singleWhere((i) => i.muscleGroup == 'Biceps');
      expect(biceps.setsInWindow, 0);
      expect(biceps.level, VolumeLevel.none);
    });

    test('multi-week windows compare weekly equivalents to the guideline', () {
      final infos = buildMuscleVolumeInfos(
        totals: {'Quads': 48.0},
        allGroups: const ['Quads'],
        weeksInWindow: 4,
      );

      final quads = infos.single;
      expect(quads.setsInWindow, 48.0);
      expect(quads.weeklySets, 12.0);
      expect(quads.level, VolumeLevel.optimal);
    });
  });

  group('formatWeightedSets', () {
    test('trims trailing .0 and keeps halves', () {
      expect(formatWeightedSets(12), '12');
      expect(formatWeightedSets(7.5), '7.5');
      expect(formatWeightedSets(0), '0');
      expect(formatWeightedSets(10.25), '10.3');
    });
  });
}
