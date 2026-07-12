import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';

/// Exercise-list template: workout name, a compact stat row, then the
/// performed exercises ("Nx  Name", accent count + white name) capped with a
/// "+N more" line, and a small anatomy hero filling any leftover space.
/// Mirrors the Hevy exercise-list card.
class ExerciseListCard extends ConsumerWidget {
  const ExerciseListCard({required this.data, super.key});

  final ShareCardData data;

  static const _maxRows = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = data.exercises.take(_maxRows).toList();
    final hidden = data.exercises.length - shown.length;

    return ShareCardFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShareCardTitle(data.workoutName, size: 28),
          const SizedBox(height: 16),
          ShareStatRow(data, valueSize: 22),
          const SizedBox(height: 24),
          for (final e in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Text('${e.sets}x', style: shareNumberStyle(18, color: kShareAccent)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kShareTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+$hidden more',
                style: const TextStyle(
                  color: kShareTextSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Center(
                child: ShareAnatomyHero(
                  groups: data.workedMuscleGroups,
                  height: c.maxHeight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
