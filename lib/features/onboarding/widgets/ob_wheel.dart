import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:my_gym_bro/features/onboarding/widgets/ob_frame.dart';
import 'package:my_gym_bro/features/onboarding/widgets/ob_widgets.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// The handoff's iOS-style 3D wheel column (238 tall, 34-unit rows).
///
/// Each row sits `offset × 34` from the centre, tilted `offset × 19°` under a
/// 600-unit perspective, shrunk 5% per row (capped at 3) and faded 20% per
/// row; the centre row reads #F2F2F2, the rest #8E8E93. Drag with inertia
/// (velocity × 140ms projection) or tap a row; it always snaps with an
/// ease-out-cubic. On first reveal it spins in from 5 rows away over .95s.
///
/// The highlight bar behind the centre row is drawn by the step — its size
/// differs per screen and one bar can span several columns.
class ObWheel extends StatefulWidget {
  const ObWheel({
    required this.itemCount,
    required this.index,
    required this.labelBuilder,
    required this.onChanged,
    this.introDelay = Duration.zero,
    this.semanticLabel,
    super.key,
  });

  final int itemCount;

  /// The selected row. Changing it from outside (e.g. a unit switch) jumps
  /// the wheel there without animation.
  final int index;
  final String Function(int index) labelBuilder;

  /// Fires whenever the row under the centre line changes (live while
  /// dragging, so dependent labels track the wheel).
  final ValueChanged<int> onChanged;

  /// Extra delay before the intro spin (the handoff staggers columns 70ms).
  final Duration introDelay;
  final String? semanticLabel;

  static const double rowHeight = 34;
  static const double height = 238;

  @override
  State<ObWheel> createState() => _ObWheelState();
}

class _ObWheelState extends State<ObWheel> with SingleTickerProviderStateMixin {
  late final AnimationController _tween;
  late double _pos = widget.index.toDouble();
  double _tweenFrom = 0;
  double _tweenTo = 0;

  /// Head of the tween run spent waiting (the intro's column stagger).
  double _tweenDelay = 0;
  bool _intro = false;
  bool _started = false;

  // Drag bookkeeping (design units).
  double _dragStartPos = 0;
  double _dragDy = 0;

  int get _last => widget.itemCount - 1;
  int get _rounded => _pos.round().clamp(0, _last);

  @override
  void initState() {
    super.initState();
    // Eager, not `late`: a wheel that never moves must not create its
    // ticker for the first time in dispose().
    _tween = AnimationController(vsync: this)..addListener(_onTweenTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final play = ObPageScope.animateInOf(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (!play) return;
    // Spin in from 5 rows away (the handoff's `introWheels`).
    _intro = true;
    _pos = math.min(widget.index + 5, _last).toDouble();
    _animateTo(
      widget.index,
      const Duration(milliseconds: 950),
      delay: const Duration(milliseconds: 120) + widget.introDelay,
    );
  }

  @override
  void didUpdateWidget(ObWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new list (unit switch) or an outside change (converted value, a
    // clamped birth day) jumps straight there, like the handoff — no tween
    // left running in the old list's index space.
    final listChanged = widget.itemCount != oldWidget.itemCount;
    if (listChanged ||
        (widget.index != oldWidget.index && widget.index != _rounded)) {
      _tween.stop();
      _intro = false;
      _pos = widget.index.clamp(0, _last).toDouble();
    }
  }

  @override
  void dispose() {
    _tween.dispose();
    super.dispose();
  }

  void _animateTo(
    int target,
    Duration duration, {
    Duration delay = Duration.zero,
  }) {
    _tweenFrom = _pos;
    _tweenTo = target.toDouble();
    if ((_tweenTo - _tweenFrom).abs() < 0.001) {
      _setPos(_tweenTo);
      _intro = false;
      return;
    }
    final total = delay + duration;
    _tweenDelay = delay.inMicroseconds / total.inMicroseconds;
    _tween
      ..duration = total
      ..forward(from: 0).whenCompleteOrCancel(() => _intro = false);
  }

  void _onTweenTick() {
    final raw = _tween.value;
    if (raw <= _tweenDelay) return;
    final t = Curves.easeOutCubic
        .transform((raw - _tweenDelay) / (1 - _tweenDelay));
    _setPos(_tweenFrom + (_tweenTo - _tweenFrom) * t);
  }

  void _setPos(double pos) {
    final before = _rounded;
    setState(() => _pos = pos);
    final after = _rounded;
    if (after != before && !_intro) {
      HapticFeedback.selectionClick();
      widget.onChanged(after);
    }
  }

  void _onDragStart(DragStartDetails _) {
    _tween.stop();
    _intro = false;
    _dragStartPos = _pos;
    _dragDy = 0;
  }

  void _onDragUpdate(DragUpdateDetails d, double scale) {
    _dragDy += d.delta.dy / scale;
    _setPos(
      (_dragStartPos - _dragDy / ObWheel.rowHeight)
          .clamp(-0.45, widget.itemCount - 0.55),
    );
  }

  void _onDragEnd(DragEndDetails d, double scale) {
    // px/s → rows/ms, upward flicks advance.
    final velocity = -d.velocity.pixelsPerSecond.dy / scale /
        ObWheel.rowHeight /
        1000;
    final target = (_pos + velocity * 140).round().clamp(0, _last);
    final ms = math.min(700, 260 + ((target - _pos).abs() * 45).round());
    _animateTo(target, Duration(milliseconds: ms));
  }

  void _onTapUp(TapUpDetails d, double scale) {
    _tween.stop();
    _intro = false;
    final fromCentre =
        (d.localPosition.dy / scale - ObWheel.height / 2) / ObWheel.rowHeight;
    final target = (_rounded + fromCentre.round()).clamp(0, _last);
    _animateTo(target, const Duration(milliseconds: 280));
  }

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final rows = <Widget>[];
    final first = math.max(0, _pos.floor() - 4);
    final lastVisible = math.min(_last, _pos.ceil() + 4);
    for (var i = first; i <= lastVisible; i++) {
      final d = i - _pos;
      final ad = d.abs();
      final opacity = math.max(0, 1 - ad * 0.2).toDouble();
      if (opacity <= 0) continue;
      rows.add(
        Positioned(
          left: 0,
          right: 0,
          top: ob(102),
          height: ob(ObWheel.rowHeight),
          child: Opacity(
            opacity: opacity,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 1 / ob(600))
                ..translateByDouble(0, ob(d * ObWheel.rowHeight), 0, 1)
                // Rows above centre tip their top edge away (a drum).
                ..rotateX(d * 19 * math.pi / 180)
                ..scaleByDouble(
                  1 - math.min(ad, 3) * 0.05,
                  1 - math.min(ad, 3) * 0.05,
                  1,
                  1,
                ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.labelBuilder(i),
                    maxLines: 1,
                    style: ob.text(
                      22,
                      weight: FontWeight.w600,
                      color: ad < 0.5
                          ? AppOnboarding.textWheel
                          : AppOnboarding.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      value: widget.labelBuilder(_rounded),
      increasedValue:
          _rounded < _last ? widget.labelBuilder(_rounded + 1) : null,
      decreasedValue: _rounded > 0 ? widget.labelBuilder(_rounded - 1) : null,
      onIncrease: _rounded < _last
          ? () => _animateTo(_rounded + 1, const Duration(milliseconds: 280))
          : null,
      onDecrease: _rounded > 0
          ? () => _animateTo(_rounded - 1, const Duration(milliseconds: 280))
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: (d) => _onDragUpdate(d, ob.scale),
        onVerticalDragEnd: (d) => _onDragEnd(d, ob.scale),
        onTapUp: (d) => _onTapUp(d, ob.scale),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, 0.3, 0.7, 1],
          ).createShader(rect),
          child: Stack(clipBehavior: Clip.none, children: rows),
        ),
      ),
    );
  }
}

/// The #1C1C1E rounded bar behind a wheel's centre row.
class ObWheelBar extends StatelessWidget {
  const ObWheelBar({this.radius = 10, super.key});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppOnboarding.card,
        borderRadius: BorderRadius.circular(ob(radius)),
      ),
    );
  }
}
