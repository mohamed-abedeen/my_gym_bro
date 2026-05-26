import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

/// Builds [MuscleStateInfo] list for a specific session's targeted muscles.
///
/// All targeted muscles are shown with the danger (red) color to indicate
/// they were worked, matching the Figma profile design.
List<MuscleStateInfo> muscleStatesForSession(EnrichedSession enriched) {
  return enriched.targetedMuscleGroups
      .map((group) => MuscleStateInfo(
            muscleGroup: group,
            state: MuscleState.recovering,
            recoveryPercent: 0.05, // low recovery = red highlight
          ))
      .toList();
}

/// Selected tab index on the profile screen (Status / Achievement / Posts).
final profileTabProvider = StateProvider<int>((ref) => 0);

/// Expanded session index in the profile session history.
/// 0 = latest session (expanded by default), -1 = none.
final profileExpandedSessionProvider = StateProvider<int>((ref) => 0);
