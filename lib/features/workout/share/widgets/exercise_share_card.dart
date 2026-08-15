import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/workout/share/exercise_share_data.dart';
import 'package:my_gym_bro/features/workout/share/share_card_frame.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// The exercise share template — an exercise's all-time story on one card:
/// masthead, the exercise name in the editorial title treatment, its lift
/// rank as a glowing hero badge (rankable classics only), the four PRs, and
/// a volume-trend sparkline. Follows the v2 handoff palette/typography via
/// the shared tokens in `share_card_widgets.dart`.
class ExerciseShareCard extends ConsumerWidget {
  const ExerciseShareCard({required this.data, super.key});

  final ExerciseShareData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final unit = ref.watch(weightUnitProvider);
    final rank = data.rankBand == null ? null : Rank.fromBand(data.rankBand!);
    final title = splitShareTitle(data.exerciseName);
    final showTrend = data.trend.length >= 2;

    return ShareCardFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 32, 30, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Masthead(data: data, l10n: l10n, locale: locale),
            const SizedBox(height: 26),
            if (data.muscleGroup != null) ...[
              Text(
                data.muscleGroup!.toUpperCase(),
                style: shareMono(11, letterSpacing: 2.5),
              ),
              const SizedBox(height: 8),
            ],
            // Editorial title treatment: metallic first line, lime-outlined
            // last word. FittedBox shrinks long exercise names per line.
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ShareMetallicText(
                  title.line1.toUpperCase(),
                  style: shareArchivo(
                    36,
                    weight: 800,
                    width: 108,
                    letterSpacing: -0.8,
                    height: 1,
                  ),
                ),
              ),
            ),
            if (title.line2 != null)
              Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title.line2!.toUpperCase(),
                    maxLines: 1,
                    style: shareOutlinedArchivo(36),
                  ),
                ),
              ),
            const Spacer(),
            if (rank != null) ...[
              _RankHero(rank: rank, l10n: l10n),
              const Spacer(),
            ],
            Text(
              l10n.sharePersonalRecords.toUpperCase(),
              style: shareMono(11, letterSpacing: 2.5),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: l10n.heaviestWeight,
                    kg: data.maxWeightKg,
                    unit: unit,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCell(
                    label: l10n.oneRepMax,
                    kg: data.best1RmKg,
                    unit: unit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: l10n.bestSetVolumeLabel,
                    kg: data.bestSetVolumeKg,
                    unit: unit,
                    decimals: 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCell(
                    label: l10n.bestSessionVolumeLabel,
                    kg: data.bestSessionVolumeKg,
                    unit: unit,
                    decimals: 0,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (showTrend) ...[
              Row(
                children: [
                  Text(
                    l10n.shareVolumeTrend.toUpperCase(),
                    style: shareMono(11, letterSpacing: 2.5),
                  ),
                  const Spacer(),
                  Text(
                    l10n.shareTrendSessions(data.trend.length).toUpperCase(),
                    style: shareMono(9, color: kShareTextTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _SparklinePainter(
                    [for (final p in data.trend) p.volumeKg],
                  ),
                ),
              ),
              const Spacer(),
            ],
            const ShareFooter(),
          ],
        ),
      ),
    );
  }
}

/// Logo + app name left · snapshot date right (the exercise card has no
/// workout number, so the date always sits in the masthead).
class _Masthead extends StatelessWidget {
  const _Masthead({required this.data, required this.l10n, required this.locale});

  final ExerciseShareData data;
  final AppLocalizations l10n;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          kShareBrandLogo,
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          opacity: const AlwaysStoppedAnimation(0.9),
        ),
        const SizedBox(width: 8),
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
          shareDateLine(data.date ?? DateTime.now(), locale),
          style: shareMono(10, letterSpacing: 2, color: kShareTextTertiary),
        ),
      ],
    );
  }
}

/// The all-time rank badge with the tier-colored glow (compact version of
/// the Ranks template's hero).
class _RankHero extends StatelessWidget {
  const _RankHero({required this.rank, required this.l10n});

  final Rank rank;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final glow = rankColors(rank.tier).gradient[1];
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.45),
                blurRadius: 60,
                spreadRadius: 10,
              ),
            ],
          ),
          child: RankBadge(rank, size: 110),
        ),
        const SizedBox(height: 12),
        Text(
          rank.label(l10n).toUpperCase(),
          textAlign: TextAlign.center,
          style: shareMono(12, letterSpacing: 2, color: kShareAccent),
        ),
      ],
    );
  }
}

/// One PR cell: mono label over an Archivo value. Null PRs render an em dash
/// (an exercise can be shared before it was ever logged).
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.kg,
    required this.unit,
    this.decimals = 1,
  });

  final String label;
  final double? kg;
  final WeightUnit unit;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final value = kg == null
        ? '—'
        : formatWeight(kg, unit, decimals: decimals, withUnit: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: shareMono(9, color: kShareTextTertiary),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: shareArchivo(21, weight: 800, letterSpacing: -0.4),
          ),
        ),
      ],
    );
  }
}

/// Lime polyline over a soft gradient fill, with a dot on the latest
/// session — per-session volume, oldest → newest.
class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final range = max - min;
    // Inset so the stroke and end dot never clip at the edges.
    const inset = 5.0;
    final usableH = size.height - inset * 2;
    final dx = (size.width - inset * 2) / (values.length - 1);

    Offset pointAt(int i) {
      final t = range == 0 ? 0.5 : (values[i] - min) / range;
      return Offset(inset + dx * i, inset + (1 - t) * usableH);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = pointAt(i);
      line.lineTo(p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(pointAt(values.length - 1).dx, size.height)
      ..lineTo(pointAt(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kShareAccent.withValues(alpha: 0.22),
            kShareAccent.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = kShareAccent,
    );
    canvas.drawCircle(
      pointAt(values.length - 1),
      3.5,
      Paint()..color = kShareAccent,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
