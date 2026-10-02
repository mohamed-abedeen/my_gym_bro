import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/refractive_glass.dart';

/// Animates a text style like [AnimatedDefaultTextStyle] but merges into the
/// ambient style, so the platform font family (SF Pro / Roboto) carries
/// through instead of being replaced.
class ObAnimatedTextStyle extends StatelessWidget {
  const ObAnimatedTextStyle({
    required this.style,
    required this.child,
    this.duration = AppOnboarding.select,
    super.key,
  });

  final TextStyle style;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<TextStyle>(
        tween: TextStyleTween(end: style),
        duration: duration,
        builder: (context, s, child) =>
            DefaultTextStyle.merge(style: s, child: child!),
        child: child,
      );
}

/// Tells a step's widgets whether they are being revealed by a forward push
/// (play their entrance) or re-shown by a back navigation (appear settled,
/// as the handoff keeps visited screens "on").
class ObPageScope extends InheritedWidget {
  const ObPageScope({
    required this.animateIn,
    required super.child,
    super.key,
  });

  final bool animateIn;

  static bool animateInOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ObPageScope>()?.animateIn ?? true;

  @override
  bool updateShouldNotify(ObPageScope oldWidget) => false;
}

/// The handoff's entrance: fade in while rising [dy] (or sliding [dx]) and
/// optionally scaling up from [scaleFrom], after [delay].
class ObEntrance extends StatefulWidget {
  const ObEntrance({
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
    this.dy = 18,
    this.dx = 0,
    this.scaleFrom = 1,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Design units.
  final double dy;
  final double dx;
  final double scaleFrom;

  @override
  State<ObEntrance> createState() => _ObEntranceState();
}

class _ObEntranceState extends State<ObEntrance>
    with SingleTickerProviderStateMixin {
  // The delay is the head of one controller run (no timers to cancel).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  late final double _start = widget.delay.inMicroseconds /
      (widget.delay + widget.duration).inMicroseconds;
  late final CurvedAnimation _move = CurvedAnimation(
    parent: _c,
    curve: Interval(_start, 1, curve: AppOnboarding.entranceCurve),
  );
  // Opacity finishes a touch before the move (.5s vs .6s in the handoff).
  late final CurvedAnimation _fade = CurvedAnimation(
    parent: _c,
    curve: Interval(_start, _start + (1 - _start) * 0.84, curve: Curves.ease),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final play = ObPageScope.animateInOf(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (play) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _fade.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final move = _move;
    final fade = _fade;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = 1 - move.value;
        var out = child!;
        if (widget.scaleFrom != 1) {
          out = Transform.scale(
            scale: widget.scaleFrom + (1 - widget.scaleFrom) * move.value,
            child: out,
          );
        }
        return Opacity(
          opacity: fade.value,
          child: Transform.translate(
            offset: Offset(ob(widget.dx * t), ob(widget.dy * t)),
            child: out,
          ),
        );
      },
    );
  }
}

/// Global header: back chevron at (28, 60) and the 4-segment progress bar at
/// (65, 73). [progress] is filled segments (0–4); null hides the bar.
class ObHeader extends StatelessWidget {
  const ObHeader({
    required this.progress,
    required this.onBack,
    this.showBack = true,
    super.key,
  });

  final double? progress;
  final VoidCallback onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ob.at(
          left: 20,
          top: 52,
          width: 48,
          height: 48,
          child: IgnorePointer(
            ignoring: !showBack,
            child: AnimatedOpacity(
              opacity: showBack ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: ObBackButton(onTap: onBack),
            ),
          ),
        ),
        ob.at(
          left: 65,
          top: 73,
          width: 331,
          height: 3,
          child: AnimatedOpacity(
            opacity: progress == null ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: ObProgressBar(progress: progress ?? 0),
          ),
        ),
      ],
    );
  }
}

/// The 26px, 2.6-stroke white chevron with a 48-unit hit area.
class ObBackButton extends StatelessWidget {
  const ObBackButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: CustomPaint(
            size: Size.square(ob(26)),
            painter: const _ChevronPainter(),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // The handoff's `polyline points="15 18 9 12 15 6"`, stroke 2.6, in a
    // 24-unit viewBox.
    final k = size.width / 24;
    final path = Path()
      ..moveTo(15 * k, 18 * k)
      ..lineTo(9 * k, 12 * k)
      ..lineTo(15 * k, 6 * k);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppOnboarding.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}

/// 4 segments with an 11-unit gap; fills animate over .5s.
class ObProgressBar extends StatelessWidget {
  const ObProgressBar({required this.progress, super.key});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) SizedBox(width: ob(11)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(ob(2)),
              child: ColoredBox(
                color: AppOnboarding.limeTrack,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (progress - i).clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 500),
                    curve: AppOnboarding.entranceCurve,
                    builder: (context, fill, _) => FractionallySizedBox(
                      widthFactor: fill,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppOnboarding.lime,
                          borderRadius: BorderRadius.circular(ob(2)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Scales its child to .97 while pressed (the handoff's `:active` state).
class ObPressable extends StatefulWidget {
  const ObPressable({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.97,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final String? semanticLabel;

  @override
  State<ObPressable> createState() => _ObPressableState();
}

class _ObPressableState extends State<ObPressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap == null || down == _down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.pressedScale : 1,
          duration: const Duration(milliseconds: 180),
          curve: AppOnboarding.entranceCurve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The onboarding's button surface in the iOS 26 "Liquid Glass" style: the
/// refractive [RefractiveGlass] with [RefractiveGlass.buttonSettings]
/// (specular arcs, a soft inner glow along the rim, slight frost, lensing at
/// the edges) over the button's own [tint] and the handoff's top-lit sheen,
/// at its 40-unit pill radius, sized by its parent.
///
/// Where the shader can't run — inside the paywall's scroll view, or on a
/// renderer without shader filters — [RefractiveGlass] falls back to frosted
/// glass with the same tint, and this paints the same specular arcs so the
/// button still reads as glass.
class ObLiquidGlass extends StatelessWidget {
  const ObLiquidGlass({required this.tint, required this.child, super.key});

  /// The dark glass of the Continue / Get Started / Start training buttons:
  /// the top of the handoff's #2C2C2E→#161618 Continue fill, at its 72%
  /// alpha (the bottom shade below supplies the darker half).
  static const dark = Color(0xB82C2C2E);

  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final radius = ob(40);
    // The handoff's `radial-gradient(120% 140% at 30% -20%, white 16%, 0 55%)`
    // — an ellipse ~4× wider than tall, so the circle is stretched on x.
    final sheen = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: RadialGradient(
          center: const Alignment(-0.4, -1.4),
          radius: 1.4,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.55],
          transform: const ObEllipse(
            center: Alignment(-0.4, -1.4),
            sx: 374 * 1.2 / (79 * 1.4),
          ),
        ),
      ),
      // …and a little shade toward the bottom, so the pill reads convex.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.14),
            ],
            stops: const [0.5, 1],
          ),
        ),
        child: child,
      ),
    );
    // The drop shadow sits BEHIND the glass. Handed to the shader package
    // instead, it is painted inside the shape, on top of the glass (Impeller
    // ignores its outer-only blur), and its 55% black buries the tint.
    return LayoutBuilder(
      builder: (context, box) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: ob(22),
              offset: Offset(0, ob(8)),
            ),
          ],
        ),
        child: RefractiveGlass(
          width: box.maxWidth,
          height: box.maxHeight,
          radius: radius,
          tint: tint,
          settings: RefractiveGlass.buttonSettings,
          child: RefractiveGlass.refractsAt(context)
              ? sheen
              : CustomPaint(
                  foregroundPainter:
                      _SpecularArcsPainter(radius: radius, width: ob(1.6)),
                  child: SizedBox.expand(child: sheen),
                ),
        ),
      ),
    );
  }
}

/// The "Continue" button (374×79, radius 40) — [ObLiquidGlass]. Label is
/// white when [enabled], #5A5A5A otherwise.
class ObGlassButton extends StatelessWidget {
  const ObGlassButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return ObPressable(
      onTap: enabled ? onTap : null,
      child: ObLiquidGlass(
        tint: ObLiquidGlass.dark,
        child: Center(
          child: ObAnimatedTextStyle(
            duration: const Duration(milliseconds: 200),
            style: ob.text(
              30,
              color: enabled
                  ? AppOnboarding.textPrimary
                  : AppOnboarding.textDisabled,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stretches a [RadialGradient] about its [center] so Flutter's circle
/// becomes a CSS `radial-gradient(ellipse …)`.
class ObEllipse extends GradientTransform {
  const ObEllipse({required this.center, this.sx = 1, this.sy = 1});

  final Alignment center;
  final double sx;
  final double sy;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final c = center.withinRect(bounds);
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }
}

/// The fallback's stand-in for the shader's rim: a thin light line all round
/// plus soft arcs on the pill's top-left cap (bright) and bottom-right cap
/// (dimmer), where the light of [RefractiveGlass.buttonSettings] and its
/// mirror hit the edge.
class _SpecularArcsPainter extends CustomPainter {
  const _SpecularArcsPainter({required this.radius, required this.width});

  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(radius, size.shortestSide / 2) - width / 2;
    void arc(Offset center, double mid, double alpha) {
      final bounds = Rect.fromCircle(center: center, radius: r);
      canvas.drawArc(
        bounds,
        mid - math.pi / 4,
        math.pi / 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.35)
          ..shader = SweepGradient(
            startAngle: mid - math.pi / 4,
            endAngle: mid + math.pi / 4,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: alpha),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(bounds),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(width / 2),
        Radius.circular(r),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.6
        ..color = Colors.white.withValues(alpha: 0.22),
    );
    final cy = size.height / 2;
    arc(Offset(r + width / 2, cy), 5 * math.pi / 4, 0.85);
    arc(Offset(size.width - r - width / 2, cy), math.pi / 4, 0.4);
  }

  @override
  bool shouldRepaint(_SpecularArcsPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.width != width;
}

/// The dark pill button (Welcome "Get Started", "Start training", the Google
/// sign-up provider) — [ObLiquidGlass] in the same dark glass as Continue.
/// (It was the handoff's solid #232323→#161616 pill until the buttons went
/// liquid glass.)
class ObDarkButton extends StatelessWidget {
  const ObDarkButton({
    required this.child,
    required this.onTap,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ObPressable(
      onTap: onTap,
      child: ObLiquidGlass(
        tint: ObLiquidGlass.dark,
        child: Center(child: child),
      ),
    );
  }
}

/// A selectable fill: lime + black text when [selected], [idle] + white
/// otherwise (the handoff's selection style — no checkmarks).
class ObChoice extends StatelessWidget {
  const ObChoice({
    required this.selected,
    required this.onTap,
    required this.radius,
    required this.child,
    this.idle = AppOnboarding.card,
    this.semanticLabel,
    super.key,
  });

  final bool selected;
  final VoidCallback onTap;

  /// Design units.
  final double radius;
  final Widget child;
  final Color idle;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return Semantics(
      selected: selected,
      label: semanticLabel,
      child: ObPressable(
        pressedScale: 0.98,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppOnboarding.select,
          decoration: BoxDecoration(
            color: selected ? AppOnboarding.lime : idle,
            borderRadius: BorderRadius.circular(ob(radius)),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: selected ? Colors.black : AppOnboarding.textPrimary,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A single-line label that animates its color with the selection and
/// shrinks to fit rather than overflowing a fixed chip.
class ObChoiceLabel extends StatelessWidget {
  const ObChoiceLabel(
    this.text, {
    required this.selected,
    required this.style,
    super.key,
  });

  final String text;
  final bool selected;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ObAnimatedTextStyle(
      style: style.copyWith(
        color: selected ? Colors.black : AppOnboarding.textPrimary,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text, maxLines: 1, textAlign: TextAlign.center),
      ),
    );
  }
}

/// FT/CM · LB/KG toggle: 374×48 track, a 185×42 lime thumb that slides over
/// .32s. [firstLabel] is the left (imperial) option.
class ObUnitToggle extends StatelessWidget {
  const ObUnitToggle({
    required this.firstLabel,
    required this.secondLabel,
    required this.secondSelected,
    required this.onChanged,
    super.key,
  });

  final String firstLabel;
  final String secondLabel;
  final bool secondSelected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    Widget option(String label, {required bool second}) {
      final active = second == secondSelected;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (active) return;
              HapticFeedback.selectionClick();
              onChanged(second);
            },
            child: Center(
              child: ObAnimatedTextStyle(
                duration: const Duration(milliseconds: 200),
                style: ob.text(
                  20,
                  color: active ? Colors.black : AppOnboarding.textPrimary,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppOnboarding.card,
        borderRadius: BorderRadius.circular(ob(24)),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: AppOnboarding.pushCurve,
            top: ob(3),
            left: ob(secondSelected ? 186 : 3),
            width: ob(185),
            height: ob(42),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppOnboarding.lime,
                borderRadius: BorderRadius.circular(ob(21)),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                option(firstLabel, second: false),
                option(secondLabel, second: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS-style switch (52×32, #34C659 when on) with the handoff's timing.
class ObSwitch extends StatelessWidget {
  const ObSwitch({required this.value, super.key});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: ob(52),
      height: ob(32),
      decoration: BoxDecoration(
        color: value ? AppOnboarding.switchOn : AppOnboarding.dotInactive,
        borderRadius: BorderRadius.circular(ob(16)),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: AppOnboarding.pushCurve,
            top: ob(2),
            left: ob(value ? 22 : 2),
            width: ob(28),
            height: ob(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: ob(6),
                    offset: Offset(0, ob(2)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
