import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart'
    show userProfileProvider;
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Shared tokens + building blocks for the v2 share-card templates
/// (design_handoff_share_cards_v2).
///
/// Colours are committed to the fixed dark handoff palette (NOT
/// `AppColors.of(context)`) so the exported PNG is identical regardless of
/// the viewer's theme. Typography is the bundled `Archivo` variable font
/// (wght/wdth axes) for display text and `IBMPlexMono` for labels/metadata.

// ── Palette ──
const kShareAccent = Color(0xFFF0FF00);
const kShareTextPrimary = Color(0xFFF4F4F0);
const kShareTextSecondary = Color(0xFF8A8A8E);
const kShareTextTertiary = Color(0xFF6E6E72);
const kShareWatermark = Color(0xFF5B5B5F);
const kShareCardBg = Color(0xFF050506);
const kShareHairline = Color(0x1FFFFFFF); // white @ 12%

/// Metallic gradient clipped to display text (titles, the volume unit).
const kShareMetallicGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFFFFF), Color(0xFFC9C9CE), Color(0xFF8E8E96)],
  stops: [0, 0.55, 1],
);

const kShareBrandLogo = 'assets/images/mgb_icon.png';

/// Whether share cards render on a transparent background (Strava-style
/// "sticker") instead of the dark canvas. Global so the Dark/Sticker toggle
/// flips every card at once; `ShareCardFrame` reads it. The exported PNG
/// keeps real alpha in sticker mode.
final shareCardTransparentProvider = StateProvider<bool>((ref) => false);

/// Archivo display style. [width] drives the variable font's wdth axis
/// (112 = expanded titles, 64 = condensed hype numerals).
TextStyle shareArchivo(
  double size, {
  double weight = 900,
  double width = 100,
  double? letterSpacing,
  double? height,
  Color? color = kShareTextPrimary,
}) =>
    TextStyle(
      fontFamily: 'Archivo',
      fontSize: size,
      color: color,
      fontWeight: FontWeight.values[weight ~/ 100 - 1],
      fontVariations: [
        FontVariation('wght', weight),
        FontVariation('wdth', width),
      ],
      letterSpacing: letterSpacing,
      height: height,
    );

/// IBM Plex Mono label style. Callers uppercase their text — every mono
/// string on the cards is uppercase by design.
TextStyle shareMono(
  double size, {
  double letterSpacing = 1.5,
  Color color = kShareTextSecondary,
  FontWeight weight = FontWeight.w400,
  double? height,
}) =>
    TextStyle(
      fontFamily: 'IBMPlexMono',
      fontSize: size,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: weight,
      height: height,
    );

/// Archivo with a lime stroke instead of a fill — the outlined title word.
TextStyle shareOutlinedArchivo(
  double size, {
  double width = 112,
  double letterSpacing = -1.2,
  double height = 0.94,
  double strokeWidth = 1.5,
}) =>
    TextStyle(
      fontFamily: 'Archivo',
      fontSize: size,
      fontWeight: FontWeight.w900,
      fontVariations: [
        const FontVariation('wght', 900),
        FontVariation('wdth', width),
      ],
      letterSpacing: letterSpacing,
      height: height,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = kShareAccent,
    );

/// Single-line text filled with the metallic gradient.
class ShareMetallicText extends StatelessWidget {
  const ShareMetallicText(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          kShareMetallicGradient.createShader(Offset.zero & bounds.size),
      child: Text(text, maxLines: 1, style: style.copyWith(color: Colors.white)),
    );
  }
}

/// Volume formatted for display: converted to the user's unit, thousands-
/// separated, split into number + unit suffix so callers can size them apart.
({String number, String unit}) shareVolumeParts(double kg, WeightUnit unit) {
  final v = convertFromKg(kg, unit);
  return (
    number: NumberFormat.decimalPattern().format(v.round()),
    unit: weightUnitLabel(unit),
  );
}

/// "12,345 kg" — the one-line form used inside stat rows and legends.
String formatShareVolume(double kg, WeightUnit unit) {
  final p = shareVolumeParts(kg, unit);
  return '${p.number} ${p.unit}';
}

/// Splits a workout title for the two-line treatment: everything before the
/// last space on line 1 (metallic/solid), the last word on line 2 (lime
/// outline). Single-word titles get line 1 only.
({String line1, String? line2}) splitShareTitle(String name) {
  final t = name.trim();
  final i = t.lastIndexOf(' ');
  if (i <= 0) return (line1: t, line2: null);
  return (line1: t.substring(0, i).trim(), line2: t.substring(i + 1));
}

/// "SUN · JUL 13 2026" — the mono date line under the card titles.
String shareDateLine(DateTime date, String locale) {
  final day = DateFormat('EEE', locale).format(date);
  final rest = DateFormat('MMM d yyyy', locale).format(date);
  return '$day · $rest'.toUpperCase();
}

/// Masthead row: [logo +] "MY GYM BRO" left · "WORKOUT #N" right. When the
/// workout number is unknown (history shares) the right side shows the date
/// if [dateFallback] is set (Hype card — it has no date elsewhere), else
/// nothing (Editorial/Anatomy already carry a date line under the title).
class ShareMasthead extends StatelessWidget {
  const ShareMasthead({
    required this.data,
    this.showLogo = true,
    this.dateFallback = false,
    super.key,
  });

  final ShareCardData data;
  final bool showLogo;
  final bool dateFallback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final String trailing;
    if (data.workoutNumber > 0) {
      trailing = l10n.shareWorkoutNumber(data.workoutNumber).toUpperCase();
    } else if (dateFallback) {
      trailing = shareDateLine(data.date ?? DateTime.now(), locale);
    } else {
      trailing = '';
    }

    return Row(
      children: [
        if (showLogo) ...[
          Image.asset(
            kShareBrandLogo,
            width: 22,
            height: 22,
            fit: BoxFit.contain,
            opacity: const AlwaysStoppedAnimation(0.9),
          ),
          const SizedBox(width: 8),
        ],
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
        Text(
          trailing,
          style: shareMono(10, letterSpacing: 2, color: kShareTextTertiary),
        ),
      ],
    );
  }
}

/// Branding footer: "MYGYMBRO.APP" watermark left [+ logo on Editorial],
/// athlete name + 24px rank badge right. [showRule] paints the hairline +
/// 14px padding above (Anatomy/Hype); Editorial spaces itself instead.
class ShareFooter extends ConsumerWidget {
  const ShareFooter({this.showRule = true, this.showLogo = false, super.key});

  final bool showRule;
  final bool showLogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rank = ref.watch(myRankProvider);
    final name = ref.watch(userProfileProvider).valueOrNull?.displayName;
    final displayName =
        (name == null || name.trim().isEmpty) ? l10n.shareAnonymous : name;

    final row = Row(
      children: [
        if (showLogo) ...[
          Image.asset(
            kShareBrandLogo,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            opacity: const AlwaysStoppedAnimation(0.85),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          'MYGYMBRO.APP',
          style: shareMono(10, letterSpacing: 2, color: kShareWatermark),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            displayName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: shareMono(10),
          ),
        ),
        if (rank != null) ...[
          const SizedBox(width: 8),
          Opacity(opacity: 0.9, child: RankBadge(rank, size: 24)),
        ],
      ],
    );

    if (!showRule) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(color: kShareHairline),
          child: SizedBox(height: 1),
        ),
        const SizedBox(height: 14),
        row,
      ],
    );
  }
}
