import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/share_helpers.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Hype template: "You lifted a total of" over a huge accent volume number,
/// with a relatable comparison headline ("That's like lifting a van!") and a
/// single big decorative icon. Mirrors the Hevy "lifting a van" card.
class VolumeHypeCard extends ConsumerWidget {
  const VolumeHypeCard({required this.data, super.key});

  final ShareCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider);
    final volume = shareVolumeParts(data.totalVolumeKg, unit);
    final comparison = volumeComparison(data.totalVolumeKg, l10n);

    return ShareCardFrame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const Icon(Icons.fitness_center_rounded, size: 72, color: kShareAccent),
          const SizedBox(height: 28),
          Text(
            l10n.shareLiftedTotal,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kShareTextSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(volume.number, style: shareNumberStyle(76, color: kShareAccent)),
                const SizedBox(width: 8),
                Text(volume.unit, style: shareNumberStyle(32, color: kShareAccent)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            comparison.headline,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: shareTitleStyle(size: 26),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
