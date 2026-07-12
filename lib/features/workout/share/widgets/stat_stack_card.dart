import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/share_helpers.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Minimal template: Duration, Volume, Sets stacked vertically and centered,
/// with an optional "NEW PR!" pill up top. Mirrors the Hevy minimal stat
/// stack.
class StatStackCard extends ConsumerWidget {
  const StatStackCard({required this.data, super.key});

  final ShareCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider);

    return ShareCardFrame(
      child: Column(
        children: [
          if (data.hasPr)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: kShareAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.newPrTitle,
                style: const TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          const Spacer(),
          ShareStatTile(
            value: formatShareDuration(data.durationSeconds),
            label: l10n.duration,
            valueSize: 52,
          ),
          const SizedBox(height: 32),
          ShareStatTile(
            value: formatShareVolume(data.totalVolumeKg, unit),
            label: l10n.volume,
            valueColor: kShareAccent,
            valueSize: 52,
          ),
          const SizedBox(height: 32),
          ShareStatTile(
            value: '${data.totalSets}',
            label: l10n.sets,
            valueSize: 52,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
