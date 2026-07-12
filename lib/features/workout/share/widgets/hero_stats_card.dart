import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Flagship template: workout name, the worked-muscle anatomy hero filling the
/// middle, and a Duration | Volume | Sets row at the bottom. Mirrors the Hevy
/// stats-and-body card.
class HeroStatsCard extends ConsumerWidget {
  const HeroStatsCard({required this.data, super.key});

  final ShareCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ShareCardFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShareCardTitle(data.workoutName, size: 32),
          if (data.workoutNumber > 0) ...[
            const SizedBox(height: 6),
            Text(
              l10n.shareWorkoutNumber(data.workoutNumber),
              style: shareLabelStyle,
            ),
          ],
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          ShareStatRow(data, valueSize: 28),
        ],
      ),
    );
  }
}
