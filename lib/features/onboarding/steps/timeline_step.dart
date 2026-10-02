import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/onboarding/onboarding_format.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_curve.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// 11 / 21 — Target timeline.
///
/// The first pass draws the curve on and settles the target marker. The
/// [optimized] pass starts fully drawn, then slides the marker left along the
/// curve while the headline date counts down, and reveals "N days sooner".
class TimelineStep extends ConsumerStatefulWidget {
  const TimelineStep({this.optimized = false, super.key});

  final bool optimized;

  @override
  ConsumerState<TimelineStep> createState() => _TimelineStepState();
}

class _TimelineStepState extends ConsumerState<TimelineStep>
    with TickerProviderStateMixin {
  static const _graphTop = 330.0;
  static const _markerX = 378.0;
  static const _slideFromX = 415.0;
  static const _slideToX = 348.0;

  /// First pass: 0–2.5s timeline of draw-on + staggered reveals.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );

  /// Optimized pass: the 1.3s marker slide.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  Timer? _pulse;
  Timer? _slideDelay;
  int _tick = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final play = ObPageScope.animateInOf(context) &&
        !MediaQuery.disableAnimationsOf(context);
    _pulse = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (mounted) setState(() => _tick++);
    });
    if (!play) {
      _intro.value = 1;
      _slide.value = 1;
      return;
    }
    if (widget.optimized) {
      _intro.value = 1;
      _slideDelay = Timer(const Duration(milliseconds: 900), () {
        if (mounted) _slide.forward();
      });
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _pulse?.cancel();
    _slideDelay?.cancel();
    _intro.dispose();
    _slide.dispose();
    super.dispose();
  }

  /// A window of the 2.5s intro, e.g. `_at(1.3, .9)` = starts at 1.3s,
  /// runs .9s.
  Animation<double> _at(double start, double length, [Curve curve = Curves.ease]) =>
      CurvedAnimation(
        parent: _intro,
        curve: Interval(start / 2.5, ((start + length) / 2.5).clamp(0, 1),
            curve: curve),
      );

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(onboardingProvider);
    final metric = data.weightMetric;
    final prediction = data.prediction();

    final draw = _at(.3, 1.5, const Cubic(0.45, 0, 0.2, 1));
    final fill = _at(1.3, .9);
    final marker = _at(1.7, .3);
    final label = _at(1.9, .4);
    final footer = _at(2, .5);
    final slide = CurvedAnimation(parent: _slide, curve: Curves.easeInOutCubic);

    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _slide]),
      builder: (context, _) {
        final t2 = widget.optimized ? slide.value : 0.0;
        final done = widget.optimized && _slide.isCompleted;
        final markerX = widget.optimized
            ? _slideFromX + (_slideToX - _slideFromX) * t2
            : _markerX;
        final markerY = ObCurve.timeline.yAt(markerX);
        final date = widget.optimized
            ? prediction.date.subtract(
                Duration(days: (t2 * prediction.soonerDays).round()),
              )
            : prediction.date;
        final ring = (widget.optimized ? done : marker.value >= 1) &&
                _tick.isOdd
            ? .22
            : 0.0;

        return ObArtboard(
          children: [
            ob.centered(
              top: 100,
              child: Text(l10n.obTimelineTitle, style: ob.text(22)),
            ),
            ob.centered(
              top: 206,
              inset: 20,
              child: ObEntrance(
                delay: const Duration(milliseconds: 100),
                dy: 0,
                duration: const Duration(milliseconds: 500),
                child: Text(l10n.obWePredict, style: ob.text(15)),
              ),
            ),
            ob.centered(
              top: 230,
              inset: 10,
              child: ObEntrance(
                delay: const Duration(milliseconds: 200),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      style: ob.text(40, letterSpacing: -0.4),
                      children: [
                        TextSpan(
                          text:
                              '${ObUnits.headlineWeight(data.effectiveTargetKg, metric: metric)} ',
                        ),
                        ...obHighlight(
                          build: l10n.obTimelineOnDate,
                          value: obShortDate(context, date),
                          highlight: const TextStyle(color: AppOnboarding.lime),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            if (widget.optimized)
              ob.centered(
                top: 288,
                child: AnimatedOpacity(
                  opacity: done ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: AnimatedSlide(
                    offset: Offset(0, done ? 0 : 0.5),
                    duration: const Duration(milliseconds: 500),
                    curve: AppOnboarding.entranceCurve,
                    child: Container(
                      height: ob(24),
                      padding: EdgeInsets.symmetric(horizontal: ob(10)),
                      decoration: BoxDecoration(
                        color: AppOnboarding.lime,
                        borderRadius: BorderRadius.circular(ob(12)),
                      ),
                      // widthFactor 1: hug the label instead of filling.
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          l10n.obDaysSooner(prediction.soonerDays),
                          style: ob.text(12,
                              weight: FontWeight.w800, color: Colors.black),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ob.at(
              left: 0,
              top: _graphTop,
              width: 440,
              height: 300,
              // The target's halo breathes with the 1.1s beat.
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: ring),
                duration: const Duration(seconds: 1),
                curve: Curves.easeInOut,
                builder: (context, halo, _) => CustomPaint(
                  painter: _TimelinePainter(
                    scale: ob.scale,
                    draw: widget.optimized ? 1 : draw.value,
                    fill: widget.optimized ? 1 : fill.value,
                    markerX: markerX,
                    markerOpacity: widget.optimized ? 1 : marker.value,
                    ring: halo,
                    oldMarkerOpacity: widget.optimized && t2 > .02 ? 1 : 0,
                  ),
                ),
              ),
            ),
            // "Today" + current weight under the start marker.
            ob.at(
              left: 12,
              top: _graphTop + 252,
              width: 80,
              child: _MarkerLabel(
                top: l10n.today,
                topColor: AppOnboarding.textMuted,
                bottom: ObUnits.weightLabel(data.weightKg, metric: metric),
              ),
            ),
            if (widget.optimized)
              ob.at(
                left: 364,
                top: _graphTop + 92,
                width: 70,
                child: AnimatedOpacity(
                  opacity: t2 > .02 ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    obShortDate(context, prediction.date),
                    textAlign: TextAlign.center,
                    style: ob
                        .text(11, color: AppOnboarding.textStruck)
                        .copyWith(
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppOnboarding.textStruck,
                        ),
                  ),
                ),
              ),
            ob.at(
              left: widget.optimized
                  ? (markerX - 45).clamp(4, 346).toDouble()
                  : 333,
              top: _graphTop + markerY + 22,
              width: 90,
              child: Opacity(
                opacity: widget.optimized ? 1 : label.value,
                child: _MarkerLabel(
                  top: obShortDate(context, date),
                  topColor: AppOnboarding.lime,
                  bottom: ObUnits.weightLabel(
                    data.effectiveTargetKg,
                    metric: metric,
                  ),
                ),
              ),
            ),
            if (!widget.optimized)
              ob.at(
                left: 45,
                right: 45,
                top: 676,
                child: Opacity(
                  opacity: footer.value,
                  child: Text(
                    l10n.obTimelineFooter,
                    textAlign: TextAlign.center,
                    style: ob.text(13, lineHeight: 17),
                  ),
                ),
              )
            else ...[
              ob.at(
                left: 30,
                right: 30,
                top: 668,
                child: AnimatedOpacity(
                  opacity: done ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: AnimatedSlide(
                    offset: Offset(0, done ? 0 : 0.6),
                    duration: const Duration(milliseconds: 600),
                    curve: AppOnboarding.entranceCurve,
                    child: Text(
                      l10n.obCloserTitle,
                      textAlign: TextAlign.center,
                      style: ob.text(16),
                    ),
                  ),
                ),
              ),
              ob.at(
                left: 55,
                right: 55,
                top: 703,
                child: AnimatedOpacity(
                  opacity: done ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  curve: const Interval(.2, 1),
                  child: Text(
                    l10n.obCloserBody,
                    textAlign: TextAlign.center,
                    style: ob.text(12, lineHeight: 15),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MarkerLabel extends StatelessWidget {
  const _MarkerLabel({
    required this.top,
    required this.topColor,
    required this.bottom,
  });

  final String top;
  final Color topColor;
  final String bottom;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return Column(
      children: [
        Text(top, maxLines: 1, style: ob.text(11, color: topColor)),
        SizedBox(height: ob(2)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(bottom, maxLines: 1, style: ob.text(15)),
        ),
      ],
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.scale,
    required this.draw,
    required this.fill,
    required this.markerX,
    required this.markerOpacity,
    required this.ring,
    required this.oldMarkerOpacity,
  });

  final double scale;
  final double draw;
  final double fill;
  final double markerX;
  final double markerOpacity;
  final double ring;
  final double oldMarkerOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    const curve = ObCurve.timeline;
    final s = scale;

    final grid = Paint()
      ..color = AppOnboarding.card
      ..strokeWidth = s;
    for (final y in const [72.0, 154.0, 236.0]) {
      canvas.drawLine(Offset(0, y * s), Offset(440 * s, y * s), grid);
    }

    if (fill > 0) {
      canvas.drawPath(
        curve.area(bottom: 300, sx: s, sy: s),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppOnboarding.lime.withValues(alpha: .16 * fill),
              AppOnboarding.lime.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTRB(0, 72 * s, 440 * s, 300 * s)),
      );
    }

    if (draw > 0) {
      final line = curve.line(sx: s, sy: s);
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * s
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [AppOnboarding.graphLine, AppOnboarding.lime],
        ).createShader(Rect.fromLTRB(0, 0, 440 * s, 300 * s));
      if (draw >= 1) {
        canvas.drawPath(line, stroke);
      } else {
        final metric = line.computeMetrics().first;
        canvas.drawPath(metric.extractPath(0, metric.length * draw), stroke);
      }
    }

    // Today marker: white dot with a black ring.
    final today = Offset(ObCurve.todayX * s, curve.startY * s);
    canvas
      ..drawCircle(today, 6 * s, Paint()..color = Colors.white)
      ..drawCircle(
        today,
        6 * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * s
          ..color = Colors.black,
      );

    // The optimized pass dims the original target point.
    if (oldMarkerOpacity > 0) {
      final old = Offset(415 * s, curve.endY * s);
      canvas
        ..drawCircle(
          old,
          6 * s,
          Paint()..color = Colors.black.withValues(alpha: oldMarkerOpacity),
        )
        ..drawCircle(
          old,
          6 * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * s
            ..color =
                AppOnboarding.graphLine.withValues(alpha: oldMarkerOpacity),
        );
    }

    final target = Offset(markerX * s, curve.yAt(markerX) * s);
    if (ring > 0) {
      canvas.drawCircle(
        target,
        16 * s,
        Paint()..color = AppOnboarding.lime.withValues(alpha: ring),
      );
    }
    if (markerOpacity > 0) {
      canvas
        ..drawCircle(
          target,
          7 * s,
          Paint()..color = AppOnboarding.lime.withValues(alpha: markerOpacity),
        )
        ..drawCircle(
          target,
          7 * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * s
            ..color = Colors.black.withValues(alpha: markerOpacity),
        );
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.scale != scale ||
      old.draw != draw ||
      old.fill != fill ||
      old.markerX != markerX ||
      old.markerOpacity != markerOpacity ||
      old.ring != ring ||
      old.oldMarkerOpacity != oldMarkerOpacity;
}
