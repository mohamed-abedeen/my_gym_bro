import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/share_helpers.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Editorial template — type-driven: masthead, giant two-line title (solid +
/// lime outline), then a ruled stat ledger (volume / sets / duration).
class EditorialShareCard extends ConsumerWidget {
  const EditorialShareCard({required this.data, super.key});

  final ShareCardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unit = ref.watch(weightUnitProvider);
    final title = splitShareTitle(data.workoutName);
    final volume = shareVolumeParts(data.totalVolumeKg, unit);

    return ShareCardFrame(
      color: const Color(0xFF0A0A0B),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 32, 30, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Masthead (text-only; the logo lives in the footer here).
            Row(
              children: [
                Text(
                  l10n.appName.toUpperCase(),
                  style: shareMono(
                    10,
                    weight: FontWeight.w600,
                    letterSpacing: 2.5,
                    color: kShareTextTertiary,
                  ),
                ),
                const Spacer(),
                if (data.workoutNumber > 0)
                  Text(
                    l10n.shareWorkoutNumber(data.workoutNumber).toUpperCase(),
                    style: shareMono(
                      10,
                      weight: FontWeight.w500,
                      letterSpacing: 2,
                      color: kShareTextTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const _Hairline(),

            // Title block.
            const SizedBox(height: 34),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title.line1.toUpperCase(),
                maxLines: 1,
                style: shareArchivo(
                  52,
                  width: 112,
                  letterSpacing: -1.5,
                  height: 0.94,
                ),
              ),
            ),
            if (title.line2 != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title.line2!.toUpperCase(),
                  maxLines: 1,
                  style: shareOutlinedArchivo(52, letterSpacing: -1.5),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              shareDateLine(data.date ?? DateTime.now(), locale),
              style: shareMono(11, letterSpacing: 2, color: kShareTextTertiary),
            ),

            const Spacer(),

            // Stat ledger.
            const _Hairline(),
            _LedgerRow(
              label: l10n.volume.toUpperCase(),
              value: Text.rich(
                TextSpan(
                  text: volume.number,
                  style: shareArchivo(
                    34,
                    weight: 800,
                    letterSpacing: -1,
                    height: 1,
                    color: kShareAccent,
                  ),
                  children: [
                    TextSpan(
                      text: ' ${volume.unit}',
                      style: shareArchivo(
                        17,
                        weight: 600,
                        height: 1,
                        color: kShareAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const _Hairline(),
            _LedgerRow(
              label: l10n.sets.toUpperCase(),
              value: Text(
                '${data.totalSets}',
                style: shareArchivo(
                  34,
                  weight: 800,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
            ),
            const _Hairline(),
            _LedgerRow(
              label: l10n.duration.toUpperCase(),
              value: _durationRich(formatShareDuration(data.durationSeconds)),
            ),
            const _Hairline(),

            const SizedBox(height: 22),
            const ShareFooter(showRule: false, showLogo: true),
          ],
        ),
      ),
    );
  }
}

/// "58m" / "1h 2m" with the digits at ledger size and the unit letters small
/// and grey, per the handoff's duration row.
Widget _durationRich(String duration) {
  final digits = shareArchivo(34, weight: 800, letterSpacing: -1, height: 1);
  final unitStyle = shareArchivo(
    17,
    weight: 600,
    height: 1,
    color: kShareTextSecondary,
  );
  return Text.rich(
    TextSpan(
      children: [
        for (final m in RegExp(r'\d+|\D+').allMatches(duration))
          TextSpan(
            text: m.group(0),
            style: RegExp(r'^\d').hasMatch(m.group(0)!) ? digits : unitStyle,
          ),
      ],
    ),
  );
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(color: kShareHairline),
        child: SizedBox(height: 1, width: double.infinity),
      );
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Text(
            label,
            style: shareMono(11, letterSpacing: 2),
          ),
          const Spacer(),
          value,
        ],
      ),
    );
  }
}
