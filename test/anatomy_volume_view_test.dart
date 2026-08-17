import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/muscle_volume.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

/// Verifies the anatomy volume lens on BOTH genders (standing rule): every
/// canonical muscle group draws at least one overlay under the volume tint,
/// and every referenced SVG asset actually exists in the bundle — catching a
/// gender variant that was never exported.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final trainedStates = [
    for (final group in MuscleRecoveryService.allMuscleGroups)
      if (group != 'Cardio')
        MuscleStateInfo(
          muscleGroup: group,
          state: MuscleState.recovering,
          recoveryPercent: 1,
        ),
  ];

  for (final gender in AnatomyGender.values) {
    testWidgets('volume lens renders every muscle overlay ($gender)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AnatomyBody(
            muscleStates: trainedStates,
            height: 280,
            gender: gender,
            tintFor: (m) => volumeColorFor(12),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final names = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .map((s) => (s.bytesLoader as SvgAssetLoader).assetName)
          .toList();

      // Every non-Cardio group resolved to at least one overlay SVG.
      expect(names.length, greaterThanOrEqualTo(trainedStates.length));

      final prefix = gender == AnatomyGender.male
          ? 'assets/anatomy/male_'
          : 'assets/anatomy/female_';
      for (final name in names) {
        expect(name, startsWith(prefix));
      }

      await tester.runAsync(() async {
        for (final name in names.toSet()) {
          await rootBundle.load(name);
        }
      });
    });
  }
}
