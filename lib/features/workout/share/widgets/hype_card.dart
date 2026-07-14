import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/share_helpers.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// The comparison bar's width in the 405-wide design space (card padding 30).
const _barWidth = 405.0 - 2 * 30;

/// Hype template — giant condensed volume numeral plus the "you vs object"
/// comparison scale from [volumeComparison].
class HypeShareCard extends ConsumerWidget {
  const HypeShareCard({required this.data, super.key});

  final ShareCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider);
    final volume = shareVolumeParts(data.totalVolumeKg, unit);
    final comparison = volumeComparison(data.totalVolumeKg, l10n);

    // Out-lifted the object: full bar, marker at the object's fraction.
    // Below it (sub-30 kg sessions): partial fill, marker at the end.
    final outlifted = data.totalVolumeKg >= comparison.objectKg;
    final fill = outlifted
        ? 1.0
        : (data.totalVolumeKg / comparison.objectKg).clamp(0.02, 1.0);
    final marker = outlifted
        ? (comparison.objectKg / data.totalVolumeKg).clamp(0.1, 0.9)
        : 1.0;

    final miniStats = [
      '${data.totalSets} ${l10n.sets}',
      formatShareDuration(data.durationSeconds),
      data.workoutName,
    ].join(' · ').toUpperCase();

    return ShareCardFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 32, 30, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShareMasthead(data: data, dateFallback: true),
            const Spacer(),

            // Label + giant condensed numeral + unit row.
            Text(
              l10n.shareTotalVolumeLifted.toUpperCase(),
              style: shareMono(11, letterSpacing: 2.5),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                volume.number,
                maxLines: 1,
                style: shareArchivo(
                  138,
                  width: 64,
                  letterSpacing: -4,
                  height: 0.84,
                  color: kShareAccent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ShareMetallicText(
                  volume.unit.toUpperCase(),
                  style: shareArchivo(30, width: 64, letterSpacing: 1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(height: 1, color: const Color(0x29FFFFFF)),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.shareOneSession.toUpperCase(),
                  style: shareMono(
                    10,
                    letterSpacing: 2,
                    color: kShareTextTertiary,
                  ),
                ),
              ],
            ),

            // Comparison module.
            const SizedBox(height: 44),
            Text(
              comparison.headline,
              maxLines: 3,
              style: shareArchivo(
                32,
                weight: 800,
                width: 108,
                letterSpacing: -0.9,
                height: 1.08,
              ),
            ),
            // 16 + the bar's 4px marker overhang = 20 to the track (handoff).
            const SizedBox(height: 16),
            _ComparisonBar(fill: fill, marker: marker),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${l10n.shareYou} · ${formatShareVolume(data.totalVolumeKg, unit)}'
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: shareMono(9, color: kShareAccent),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '${comparison.objectLabel} · ${formatShareVolume(comparison.objectKg, unit)}'
                        .toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: shareMono(9),
                  ),
                ),
              ],
            ),

            const Spacer(),
            Text(miniStats, style: shareMono(11, letterSpacing: 2)),
            const SizedBox(height: 18),
            const ShareFooter(),
          ],
        ),
      ),
    );
  }
}

/// 8px track with a lime gradient fill and a 2×16 white marker.
class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({required this.fill, required this.marker});

  /// 0–1 fraction of the track that is lime.
  final double fill;

  /// 0–1 position of the white marker along the track.
  final double marker;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 0,
            child: Container(
              height: 8,
              width: _barWidth * fill,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [Color(0x59F0FF00), kShareAccent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: (_barWidth * marker - 1).clamp(0, _barWidth - 2),
            child: Container(width: 2, height: 16, color: kShareTextPrimary),
          ),
        ],
      ),
    );
  }
}
