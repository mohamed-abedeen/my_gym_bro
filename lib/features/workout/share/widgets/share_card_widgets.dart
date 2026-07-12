import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_helpers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

/// Shared building blocks + fixed dark palette for the share-card templates.
///
/// Colours are committed to the dark look (NOT `AppColors.of(context)`) so the
/// exported PNG is identical regardless of the viewer's theme — matching the
/// palette `ShareCardFrame` paints its background with.
const kShareAccent = Color(0xFFF0FF00);
const kShareTextPrimary = Color(0xFFFFFFFF);
const kShareTextSecondary = Color(0xFF999999);

/// Whether share cards render on a transparent background (Strava-style
/// "sticker") instead of the dark canvas. Global so the Normal/Transparent
/// toggle flips every card at once; `ShareCardFrame` reads it. The exported
/// PNG keeps real alpha in transparent mode.
final shareCardTransparentProvider = StateProvider<bool>((ref) => false);

/// Big-number style: Familjen Grotesk, tight, for the hero stat figures.
TextStyle shareNumberStyle(double size, {Color color = kShareTextPrimary}) =>
    GoogleFonts.familjenGrotesk(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1,
      letterSpacing: -0.5,
    );

/// Card title (workout name) style — same Familjen dialect as the numbers.
TextStyle shareTitleStyle({double size = 30}) => GoogleFonts.familjenGrotesk(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: kShareTextPrimary,
      height: 1.05,
      letterSpacing: -0.5,
    );

/// Small grey uppercase stat label.
const shareLabelStyle = TextStyle(
  color: kShareTextSecondary,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 1,
);

/// Volume formatted for display: converted to the user's unit, thousands-
/// separated, split into number + unit suffix so callers can size them apart.
({String number, String unit}) shareVolumeParts(double kg, WeightUnit unit) {
  final v = convertFromKg(kg, unit);
  return (
    number: NumberFormat.decimalPattern().format(v.round()),
    unit: weightUnitLabel(unit),
  );
}

/// "12,345 kg" — the one-line form used inside stat rows.
String formatShareVolume(double kg, WeightUnit unit) {
  final p = shareVolumeParts(kg, unit);
  return '${p.number} ${p.unit}';
}

/// Card title (workout name), truncated to two lines.
class ShareCardTitle extends StatelessWidget {
  const ShareCardTitle(
    this.text, {
    this.size = 30,
    this.textAlign = TextAlign.left,
    super.key,
  });

  final String text;
  final double size;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: shareTitleStyle(size: size),
    );
  }
}

/// A single stat: big Familjen-Grotesk number over a small grey label.
class ShareStatTile extends StatelessWidget {
  const ShareStatTile({
    required this.value,
    required this.label,
    this.valueColor = kShareTextPrimary,
    this.valueSize = 26,
    super.key,
  });

  final String value;
  final String label;
  final Color valueColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: shareNumberStyle(valueSize, color: valueColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(label.toUpperCase(), style: shareLabelStyle),
      ],
    );
  }
}

/// The Duration | Volume | Sets stat row shared by the flagship cards. Reads
/// the user's weight unit so volume displays converted + thousands-separated.
class ShareStatRow extends ConsumerWidget {
  const ShareStatRow(this.data, {this.valueSize = 26, super.key});

  final ShareCardData data;
  final double valueSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider);
    return Row(
      children: [
        Expanded(
          child: ShareStatTile(
            value: formatShareDuration(data.durationSeconds),
            label: l10n.duration,
            valueSize: valueSize,
          ),
        ),
        Expanded(
          child: ShareStatTile(
            value: formatShareVolume(data.totalVolumeKg, unit),
            label: l10n.volume,
            valueColor: kShareAccent,
            valueSize: valueSize,
          ),
        ),
        Expanded(
          child: ShareStatTile(
            value: '${data.totalSets}',
            label: l10n.sets,
            valueSize: valueSize,
          ),
        ),
      ],
    );
  }
}

/// The worked-muscle anatomy hero, accent-highlighted, sized to [height].
/// Renders plain when [groups] is empty.
class ShareAnatomyHero extends ConsumerWidget {
  const ShareAnatomyHero({
    required this.groups,
    required this.height,
    super.key,
  });

  final Set<String> groups;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnatomyBody(
      height: height,
      gender: ref.watch(anatomyGenderProvider),
      basePngPath: ref.watch(activeSkinPathProvider),
      highlightColor: kShareAccent,
      muscleStates: [
        for (final g in groups)
          MuscleStateInfo(
            muscleGroup: g,
            state: MuscleState.recovering,
            recoveryPercent: 0,
          ),
      ],
    );
  }
}
