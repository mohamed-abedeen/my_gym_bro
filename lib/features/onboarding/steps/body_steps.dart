import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_format.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_layered_image.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

Duration _s(double seconds) =>
    Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());

/// The handoff's 1.1s heartbeat that drives pulses and cycles. Counts from
/// 0 each time the step mounts.
mixin _Ticker<T extends StatefulWidget> on State<T> {
  int tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (mounted) setState(() => tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 05 — Muscle focus
// ─────────────────────────────────────────────────────────────────────────────

/// Leader lines from each muscle to its pill (design units). The male render
/// has the grey dashed guides baked in; the female one gets them drawn.
const _maleLines = <FocusArea, List<Offset>>{
  FocusArea.back: [Offset(171, 295), Offset(185, 287), Offset(285, 287)],
  FocusArea.chest: [Offset(162, 348), Offset(285, 348)],
  FocusArea.arms: [
    Offset(82, 380),
    Offset(235, 380),
    Offset(252, 409),
    Offset(285, 409),
  ],
  FocusArea.abs: [Offset(130, 415), Offset(160, 470), Offset(285, 470)],
  FocusArea.glutes: [
    Offset(103, 475),
    Offset(228, 493),
    Offset(250, 531),
    Offset(285, 531),
  ],
  FocusArea.legs: [Offset(178, 540), Offset(205, 593), Offset(285, 593)],
};

const _femaleLines = <FocusArea, List<Offset>>{
  FocusArea.back: [
    Offset(84, 323),
    Offset(240, 323),
    Offset(262, 287),
    Offset(285, 287),
  ],
  FocusArea.chest: [
    Offset(161, 341),
    Offset(250, 341),
    Offset(258, 348),
    Offset(285, 348),
  ],
  FocusArea.arms: [
    Offset(72, 365),
    Offset(230, 365),
    Offset(256, 409),
    Offset(285, 409),
  ],
  FocusArea.abs: [
    Offset(134, 376),
    Offset(220, 376),
    Offset(262, 470),
    Offset(285, 470),
  ],
  FocusArea.glutes: [
    Offset(104, 420),
    Offset(215, 420),
    Offset(262, 531),
    Offset(285, 531),
  ],
  FocusArea.legs: [
    Offset(83, 538),
    Offset(230, 538),
    Offset(262, 593),
    Offset(285, 593),
  ],
};

class FocusStep extends ConsumerWidget {
  const FocusStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final focus = ref.watch(onboardingProvider.select((d) => d.focus));
    final female = ref.watch(onboardingProvider.select((d) => d.isFemale));
    final notifier = ref.read(onboardingProvider.notifier);
    final all = focus.contains(FocusArea.fullBody);
    final lines = female ? _femaleLines : _maleLines;

    return ObArtboard(
      children: [
        ob.at(
          left: 40,
          right: 40,
          top: 98,
          child: Text(
            l10n.obFocusTitle,
            textAlign: TextAlign.center,
            style: ob.text(22, lineHeight: 30),
          ),
        ),
        ob.at(
          left: 20,
          top: 210,
          width: female ? 220 : 262,
          height: 545,
          child: ObEntrance(
            delay: _s(.05),
            duration: const Duration(milliseconds: 800),
            dy: 0,
            child: Image.asset(
              female
                  ? 'assets/onboarding/focusF_body.png'
                  : 'assets/onboarding/focus_body.png',
              fit: BoxFit.fill,
              excludeFromSemantics: true,
            ),
          ),
        ),
        for (final entry in lines.entries)
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  end: all || focus.contains(entry.key) ? 1 : 0,
                ),
                duration: const Duration(milliseconds: 350),
                curve: AppOnboarding.entranceCurve,
                builder: (context, t, _) => CustomPaint(
                  painter: _LeaderLinePainter(
                    points: entry.value,
                    progress: t,
                    scale: ob.scale,
                    drawGuide: female,
                  ),
                ),
              ),
            ),
          ),
        for (final (i, area) in FocusArea.values.indexed)
          ob.at(
            left: 285,
            top: 267 + i * 61.0,
            width: 122,
            height: 40,
            child: ObEntrance(
              delay: _s(.12 + i * .05),
              duration: const Duration(milliseconds: 550),
              dy: 0,
              dx: 28,
              child: ObChoice(
                selected: all || focus.contains(area),
                onTap: () => notifier.toggleFocus(area),
                radius: 20,
                idle: AppOnboarding.pill,
                semanticLabel: l10n.focusLabel(area),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: ob(8)),
                    child: ObChoiceLabel(
                      l10n.focusLabel(area),
                      selected: all || focus.contains(area),
                      style: ob.text(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LeaderLinePainter extends CustomPainter {
  _LeaderLinePainter({
    required this.points,
    required this.progress,
    required this.scale,
    required this.drawGuide,
  });

  final List<Offset> points;
  final double progress;
  final double scale;
  final bool drawGuide;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [for (final p in points) p * scale];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    if (drawGuide) {
      // 1.5-wide #6B6B6B guide, dashed 4/4.
      final guide = Paint()
        ..color = AppOnboarding.textFigure
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * scale;
      for (final metric in path.computeMetrics()) {
        var d = 0.0;
        while (d < metric.length) {
          canvas.drawPath(metric.extractPath(d, d + 4 * scale), guide);
          d += 8 * scale;
        }
      }
    }

    if (progress > 0) {
      final lime = Paint()
        ..color = AppOnboarding.lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale;
      final metrics = path.computeMetrics().toList();
      final total = metrics.fold<double>(0, (a, m) => a + m.length);
      var left = total * progress;
      for (final m in metrics) {
        if (left <= 0) break;
        canvas.drawPath(m.extractPath(0, left.clamp(0, m.length)), lime);
        left -= m.length;
      }
    }

    // The 5-unit muscle dot: fades in (male) or turns lime (female).
    final dot = drawGuide
        ? Color.lerp(AppOnboarding.textMuted, AppOnboarding.lime, progress)!
        : AppOnboarding.lime.withValues(alpha: progress);
    canvas.drawCircle(pts.first, 5 * scale, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_LeaderLinePainter old) =>
      old.progress != progress ||
      old.scale != scale ||
      old.drawGuide != drawGuide ||
      old.points != points;
}

// ─────────────────────────────────────────────────────────────────────────────
// 15 — Injuries
// ─────────────────────────────────────────────────────────────────────────────

class InjuriesStep extends ConsumerStatefulWidget {
  const InjuriesStep({super.key});

  @override
  ConsumerState<InjuriesStep> createState() => _InjuriesStepState();
}

class _InjuriesStepState extends ConsumerState<InjuriesStep>
    with _Ticker<InjuriesStep> {
  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final g = data.isFemale ? 'injuryF' : 'injury';
    final beat = tick.isEven;

    Widget chip(int i, String label, {required bool on, required VoidCallback onTap}) =>
        ObEntrance(
          delay: _s(.25 + i * .04),
          duration: const Duration(milliseconds: 550),
          child: SizedBox(
            width: ob(123),
            height: ob(42),
            child: ObChoice(
              selected: on,
              onTap: onTap,
              radius: 21,
              semanticLabel: label,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ob(8)),
                  child: ObChoiceLabel(label, selected: on, style: ob.text(15)),
                ),
              ),
            ),
          ),
        );

    return ObArtboard(
      children: [
        ob.at(
          left: 50,
          right: 50,
          top: 98,
          child: Text(
            l10n.obInjuriesTitle,
            textAlign: TextAlign.center,
            style: ob.text(22, lineHeight: 28),
          ),
        ),
        ob.at(
          left: 40,
          top: 250,
          width: 370,
          height: 390,
          child: ObEntrance(
            delay: _s(.05),
            duration: const Duration(milliseconds: 800),
            dy: 0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/onboarding/${g}_base.png',
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
                for (final area in InjuryArea.values) ...[
                  // Blurred halo, then the crisp red core; both pulse.
                  AnimatedOpacity(
                    opacity: data.injuries.contains(area) ? (beat ? .85 : .25) : 0,
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeInOut,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: ob(8),
                        sigmaY: ob(8),
                      ),
                      child: Image.asset(
                        'assets/onboarding/${g}_glow_${area.wire}.png',
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: data.injuries.contains(area) ? (beat ? 1 : .55) : 0,
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeInOut,
                    child: Image.asset(
                      'assets/onboarding/${g}_glow_${area.wire}.png',
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ob.at(
          left: 26,
          top: 672,
          width: 388,
          child: Wrap(
            spacing: ob(9),
            runSpacing: ob(7),
            children: [
              for (final (i, area) in InjuryArea.values.indexed)
                chip(
                  i,
                  l10n.injuryLabel(area),
                  on: data.injuries.contains(area),
                  onTap: () => notifier.toggleInjury(area),
                ),
              chip(
                InjuryArea.values.length,
                l10n.obInjuryNone,
                on: data.noInjuries,
                onTap: notifier.toggleNoInjuries,
              ),
            ],
          ),
        ),
        // Not in the handoff: the app plans around injuries (rest days,
        // keeping the area out of heavy work), so say plainly that it isn't
        // medical advice — same line as the Terms' health section.
        ob.at(
          left: 56,
          right: 56,
          top: 782,
          child: ObEntrance(
            delay: _s(.5),
            child: Text(
              l10n.obInjuryDisclaimer,
              textAlign: TextAlign.center,
              style: ob.text(
                12,
                weight: FontWeight.w500,
                color: AppOnboarding.textMuted,
                lineHeight: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 17 — Muscle recovery
// ─────────────────────────────────────────────────────────────────────────────

/// Base + red/orange/green layers for the recovery body map; the female
/// layers screen-blend like the handoff.
class ObRecoveryMap extends StatelessWidget {
  const ObRecoveryMap({
    required this.female,
    this.opacities = const [1, 1, 1],
    super.key,
  });

  final bool female;

  /// Red, orange, green.
  final List<double> opacities;

  @override
  Widget build(BuildContext context) {
    final g = female ? 'recoveryF' : 'recovery';
    return ObLayeredImage(
      base: 'assets/onboarding/${g}_base.png',
      layers: [
        'assets/onboarding/${g}_red.png',
        'assets/onboarding/${g}_orange.png',
        'assets/onboarding/${g}_green.png',
      ],
      opacities: opacities,
      blendMode: female ? BlendMode.screen : BlendMode.srcOver,
    );
  }
}

class RecoveryStep extends ConsumerStatefulWidget {
  const RecoveryStep({super.key});

  @override
  ConsumerState<RecoveryStep> createState() => _RecoveryStepState();
}

class _RecoveryStepState extends ConsumerState<RecoveryStep>
    with _Ticker<RecoveryStep> {
  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final female = ref.watch(onboardingProvider.select((d) => d.isFemale));
    // All three layers show for two beats, then the legend cycles.
    final hl = tick >= 2 ? (tick - 2) % 3 : -1;
    double layer(int j) => hl < 0 || hl == j ? 1 : 0.2;

    final legend = [
      (AppOnboarding.fatigued, l10n.obFatigued, l10n.obFatiguedDesc),
      (AppOnboarding.recovering, l10n.recovering, l10n.obRecoveringDesc),
      (AppOnboarding.recovered, l10n.recovered, l10n.obRecoveredDesc),
    ];

    return ObArtboard(
      children: [
        ob.centered(
          top: 100,
          inset: 24,
          child: Text(l10n.obRecoveryTitle, style: ob.text(22)),
        ),
        ob.at(
          left: 40,
          top: 180,
          width: 370,
          height: 425,
          child: ObEntrance(
            delay: _s(.05),
            dy: 0,
            child: ObRecoveryMap(
              female: female,
              opacities: [layer(0), layer(1), layer(2)],
            ),
          ),
        ),
        ob.at(
          left: 40,
          right: 40,
          top: 618,
          child: ObEntrance(
            delay: _s(.4),
            dy: 0,
            child: Text(
              l10n.obRecoveryBody,
              textAlign: TextAlign.center,
              style: ob.text(15, weight: FontWeight.w600, lineHeight: 19),
            ),
          ),
        ),
        ob.at(
          left: 72,
          top: 666,
          width: 296,
          child: Column(
            children: [
              for (final (j, (color, label, desc)) in legend.indexed) ...[
                if (j > 0) SizedBox(height: ob(4)),
                ObEntrance(
                  delay: _s(.5 + j * .08),
                  child: AnimatedOpacity(
                    opacity: hl < 0 || hl == j ? 1 : 0.45,
                    duration: const Duration(milliseconds: 400),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: ob(44),
                      padding: EdgeInsets.symmetric(horizontal: ob(16)),
                      decoration: BoxDecoration(
                        color: hl == j
                            ? AppOnboarding.card
                            : AppOnboarding.card.withValues(alpha: 0),
                        borderRadius: BorderRadius.circular(ob(22)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: ob(10),
                            height: ob(10),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: ob(14)),
                          SizedBox(
                            width: ob(96),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                label,
                                maxLines: 1,
                                style: ob.text(15),
                              ),
                            ),
                          ),
                          SizedBox(width: ob(14)),
                          Expanded(
                            child: Text(
                              desc,
                              maxLines: 2,
                              style: ob.text(12,
                                  weight: FontWeight.w600,
                                  color: AppOnboarding.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 19 — Compete
// ─────────────────────────────────────────────────────────────────────────────

class CompeteStep extends ConsumerStatefulWidget {
  const CompeteStep({super.key});

  @override
  ConsumerState<CompeteStep> createState() => _CompeteStepState();
}

class _CompeteStepState extends ConsumerState<CompeteStep>
    with _Ticker<CompeteStep> {
  static const _tiers = RankTier.values;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final act = tick % _tiers.length;
    final rank = Rank(_tiers[act], 3);
    final points = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    // Illustrative board — placeholder names and scores (per the handoff).
    final board = [
      ('1', 'Karim', RankTier.gold, 12480, false),
      ('2', 'Youssef', RankTier.gold, 11920, false),
      ('3', l10n.obYou, RankTier.silver, 11305, true),
    ];

    return ObArtboard(
      children: [
        ob.centered(
          top: 100,
          inset: 24,
          child: Text(l10n.obCompeteTitle, style: ob.text(22)),
        ),
        ob.at(
          left: 120,
          top: 160,
          width: 200,
          height: 200,
          child: ObEntrance(
            delay: _s(.1),
            dy: 0,
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final (i, tier) in _tiers.indexed)
                  AnimatedOpacity(
                    opacity: i == act ? 1 : 0,
                    duration: const Duration(milliseconds: 450),
                    child: AnimatedScale(
                      scale: i == act ? 1 : 0.9,
                      duration: const Duration(milliseconds: 600),
                      curve: AppOnboarding.entranceCurve,
                      child: Image.asset(
                        'assets/badges/${tier.name}_3.png',
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ob.centered(
          top: 364,
          child: Text(
            rank.tierLabel(l10n).toUpperCase(),
            style: ob.display(40, lineHeight: 44, letterSpacing: 1),
          ),
        ),
        ob.centered(
          top: 410,
          child: Text(
            l10n.obTierLabel(_tiers[act].name),
            style: ob.text(12, color: AppOnboarding.textMuted),
          ),
        ),
        ob.at(
          left: 62,
          top: 483,
          width: 316,
          height: 2,
          child: ColoredBox(
            color: AppOnboarding.track,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: act / (_tiers.length - 1)),
                duration: const Duration(milliseconds: 600),
                curve: AppOnboarding.entranceCurve,
                builder: (context, fill, _) => FractionallySizedBox(
                  widthFactor: fill,
                  heightFactor: 1,
                  child: const ColoredBox(color: AppOnboarding.lime),
                ),
              ),
            ),
          ),
        ),
        for (final (i, tier) in _tiers.indexed)
          ob.at(
            left: 40 + i * 79.0,
            top: 462,
            width: 44,
            height: 44,
            child: ObEntrance(
              delay: _s(.2 + i * .06),
              duration: const Duration(milliseconds: 400),
              dy: 0,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppOnboarding.background,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: i == act ? 1.15 : 0.9,
                    duration: const Duration(milliseconds: 450),
                    curve: AppOnboarding.entranceCurve,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: i <= act ? 0 : 1),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, grey, child) => ColorFiltered(
                        colorFilter: _greyscale(grey, 1 - grey * 0.55),
                        child: child,
                      ),
                      child: Image.asset(
                        'assets/badges/${tier.name}_3.png',
                        width: ob(40),
                        height: ob(40),
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ob.at(
          left: 33,
          top: 540,
          width: 374,
          child: ObEntrance(
            delay: _s(.4),
            duration: const Duration(milliseconds: 700),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ob(18),
                vertical: ob(6),
              ),
              decoration: BoxDecoration(
                color: AppOnboarding.card2,
                borderRadius: BorderRadius.circular(ob(24)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: ob(40),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.obLeaderboardWeek,
                            style: ob.text(12, color: AppOnboarding.textMuted),
                          ),
                        ),
                        Text(
                          l10n.obPoints,
                          style: ob.text(12, color: AppOnboarding.textMuted),
                        ),
                      ],
                    ),
                  ),
                  for (final (pos, name, tier, pts, me) in board)
                    Container(
                      height: ob(56),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppOnboarding.divider),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: ob(16),
                            child: Text(
                              pos,
                              style: ob.mono(14,
                                  color: me
                                      ? AppOnboarding.lime
                                      : AppOnboarding.textMuted),
                            ),
                          ),
                          SizedBox(width: ob(14)),
                          Image.asset(
                            'assets/badges/${tier.name}_3.png',
                            width: ob(30),
                            height: ob(30),
                            excludeFromSemantics: true,
                          ),
                          SizedBox(width: ob(14)),
                          Expanded(
                            child: Text(
                              name,
                              style: ob.text(16,
                                  color: me
                                      ? AppOnboarding.lime
                                      : AppOnboarding.textPrimary),
                            ),
                          ),
                          Text(
                            points.format(pts),
                            style: ob.mono(15,
                                color: me
                                    ? AppOnboarding.lime
                                    : AppOnboarding.textPrimary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// CSS `grayscale(g) brightness(b)` as one color matrix.
  static ColorFilter _greyscale(double g, double b) {
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    double m(double identity, double lum) =>
        (identity * (1 - g) + lum * g) * b;
    return ColorFilter.matrix([
      m(1, lr), m(0, lg), m(0, lb), 0, 0, //
      m(0, lr), m(1, lg), m(0, lb), 0, 0, //
      m(0, lr), m(0, lg), m(1, lb), 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  }
}
