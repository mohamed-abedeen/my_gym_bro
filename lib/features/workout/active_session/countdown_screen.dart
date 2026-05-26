import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Pre-workout countdown sequence — matches Figma frames 12a–12d.
///
/// Shows 4 stages: "Ready?" → 3 → 2 → 1 with a circular progress ring
/// that depletes from accent green to olive-grey. Each stage shows a subtitle
/// pulled from the workout data (day label, exercise count, estimated time, "Lets go").
///
/// Background features two animated radial gradient orbs that shift position per stage.
///
/// Pops with `true` when complete (caller starts the session).
class CountdownScreen extends StatefulWidget {

  const CountdownScreen({
    super.key,
    this.dayLabel = 'Leg Day',
    this.exerciseCount = 5,
    this.estimatedTime = '1h',
  });
  final String dayLabel;
  final int exerciseCount;
  final String estimatedTime;

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen>
    with TickerProviderStateMixin {
  int _stage = 0; // 0=Ready, 1=3, 2=2, 3=1
  late AnimationController _ringController;
  late AnimationController _orbController;
  Timer? _stageTimer;

  static const _stageDurationMs = 1000;
  static const _ringTargets = [1.0, 0.75, 0.50, 0.25];
  double _ringProgress = 1;

  // Orb positions per stage (from Figma CSS positions):
  // Each entry: [orb1Left, orb1Top, orb2Left, orb2Top]
  static const _orbPositions = [
    // Stage 0 (Ready?): orb1 at bottom-left, orb2 at top-right
    [-302.0, 573.0, 125.0, -400.0],
    // Stage 1 (3): orb1 at bottom-right, orb2 at top-left
    [126.0, 573.0, -302.0, -352.0],
    // Stage 2 (2): orb1 rotated right, orb2 rotated left
    [260.0, 476.0, -194.0, -200.0],
    // Stage 3 (1): orb1 bottom-left, orb2 top-right
    [-194.0, 468.0, 239.0, -200.0],
  ];

  // Orb colors per stage
  static const _orb1Colors = [
    Color(0xFF4E5F00),
    Color(0xFF4E5F00),
    Color(0xFF4E5F00),
    Color(0xFF4E5F00),
  ];
  static const _orb2Colors = [
    Color(0xFF295F00),
    Color(0xFF295F00),
    Color(0xFF295F00),
    Color(0xFF295F00),
  ];

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
      final from = _stage == 0 ? 1.0 : _ringTargets[_stage - 1];
      final to = _ringTargets[_stage];
      setState(() {
        _ringProgress =
            from +
            (to - from) * Curves.easeOut.transform(_ringController.value);
      });
    });
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _orbController.forward(from: 0);
    _scheduleStageAdvance();
  }

  void _scheduleStageAdvance() {
    _stageTimer = Timer(const Duration(milliseconds: _stageDurationMs), () {
      if (_stage < 3) {
        setState(() => _stage++);
        _ringController.forward(from: 0);
        _orbController.forward(from: 0);
        _scheduleStageAdvance();
      } else {
        if (mounted) Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _stageTimer?.cancel();
    _ringController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final labels = ['Ready ?', '3', '2', '1'];
    final subtitles = [
      widget.dayLabel,
      '${widget.exerciseCount} Workouts',
      widget.estimatedTime,
      'Lets go',
    ];

    // Ring sizes from Figma
    final ringSize = 326.0.w;

    return Scaffold(
      backgroundColor: colors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_ringController, _orbController]),
        builder: (context, _) {
          return Stack(
            children: [
              // ── Background gradient orbs ──
              ..._buildOrbs(),

              // ── Centered ring + text ──
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Spacer to push down to ~323px from top in Figma
                    SizedBox(height: 40.h),

                    // Ring + label
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: _ringProgress,
                          stage: _stage,
                          strokeWidth: 20.w,
                          accentColor: colors.accent,
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              labels[_stage],
                              key: ValueKey(_stage),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: _stage == 0 ? 48.sp : 96.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // Subtitle
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: Text(
                        subtitles[_stage],
                        key: ValueKey('sub_$_stage'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 36.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildOrbs() {
    final prevStage = _stage > 0 ? _stage - 1 : 0;
    final t = _orbController.value;

    // Interpolate orb positions between stages
    final prevPos = _orbPositions[prevStage];
    final currPos = _orbPositions[_stage];

    final orb1Left = _lerpDouble(prevPos[0], currPos[0], t);
    final orb1Top = _lerpDouble(prevPos[1], currPos[1], t);
    final orb2Left = _lerpDouble(prevPos[2], currPos[2], t);
    final orb2Top = _lerpDouble(prevPos[3], currPos[3], t);

    const orbSize = 685.0;

    return [
      // Orb 1
      Positioned(
        left: orb1Left.w,
        top: orb1Top.h,
        child: Container(
          width: orbSize.w,
          height: orbSize.w,
          decoration: ShapeDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.44, 0.57),
              radius: 0.44,
              colors: [_orb1Colors[_stage], AppColors.of(context).black],
            ),
            shape: const OvalBorder(),
          ),
        ),
      ),
      // Orb 2
      Positioned(
        left: orb2Left.w,
        top: orb2Top.h,
        child: Container(
          width: orbSize.w,
          height: orbSize.w,
          decoration: ShapeDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.44, 0.57),
              radius: 0.44,
              colors: [_orb2Colors[_stage], AppColors.of(context).black],
            ),
            shape: const OvalBorder(),
          ),
        ),
      ),
    ];
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Draws the circular progress ring matching Figma design.
///
/// - Full ring: accent green (#D2FF00)
/// - Track: olive-grey (#4B4F24)
/// - Stroke width: 20px
/// - Dot at end of progress arc
class _RingPainter extends CustomPainter {

  _RingPainter({
    required this.progress,
    required this.stage,
    required this.strokeWidth,
    required this.accentColor,
  });
  final double progress; // 1.0 = full, 0.0 = empty
  final int stage;
  final double strokeWidth;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    // Background track ring (olive-grey from Figma)
    final bgPaint =
        Paint()
          ..color =
              stage == 0
                  ? const Color(0xFF333333) // "Ready?" frame uses darker grey
                  : const Color(0xFF4B4F24) // Countdown frames use olive-grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring (accent green)
    if (progress > 0) {
      final fgPaint =
          Paint()
            ..color = accentColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        fgPaint,
      );

      // Glowing dot at the tip of the progress arc
      final dotAngle = -math.pi / 2 + 2 * math.pi * progress;
      final dotCenter = Offset(
        center.dx + radius * math.cos(dotAngle),
        center.dy + radius * math.sin(dotAngle),
      );

      // Outer glow
      final glowPaint =
          Paint()
            ..color = accentColor.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(dotCenter, strokeWidth * 0.6, glowPaint);

      // Solid dot
      final dotPaint = Paint()..color = accentColor;
      canvas.drawCircle(dotCenter, strokeWidth * 0.35, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.stage != stage || old.accentColor != accentColor;
}
