import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/exercise_dao.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/constants.dart';
import '../../../shared/responsive.dart';
import '../../../shared/widgets/inline_editable_field.dart';
import '../../../shared/widgets/liquid_glass_button.dart';
import '../../../shared/widgets/oc_glass_btn.dart';
import '../workout_providers.dart';
import 'active_session_notifier.dart';
import 'rest_timer_service.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  /// Optional schedule day ID to pre-load exercises from a schedule.
  final int? scheduleDayId;

  const ActiveSessionScreen({super.key, this.scheduleDayId});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  Timer? _durationTimer;
  int _elapsedSeconds = 0;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(activeSessionProvider.notifier)
          .startSession(scheduleDayId: widget.scheduleDayId);
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isPaused) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    // Invalidate providers so the workout/home screens refresh after session ends
    ref.invalidate(muscleRecoveryProvider);
    ref.invalidate(enrichedRecentSessionsProvider);
    ref.invalidate(weeklyStatsProvider);
    ref.invalidate(recentSessionsProvider);
    super.dispose();
  }

  void _togglePause() => setState(() => _isPaused = !_isPaused);

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(activeSessionProvider);
    final notifier = ref.read(activeSessionProvider.notifier);
    final exercise = session.currentExercise;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Main scrollable content ──
          Column(
            children: [
              // Exercise image area
              _ExerciseImageArea(
                exercise: exercise,
                onMenuTap: () => _showMenuSheet(context, session, notifier),
              ),

              // Progress pills
              _ProgressPills(
                total: session.exercises.length,
                current: session.currentExerciseIndex,
                onTap: (i) => notifier.selectExercise(i),
              ),

              SizedBox(height: 6.h),

              // Exercise name
              Padding(
                padding: EdgeInsets.only(left: 25.w),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    exercise?.name ?? l10n.addExercise,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 8.h),

              // Sets table
              Expanded(
                child: exercise != null
                    ? _SetsTable(
                        exercise: exercise,
                        notifier: notifier,
                        l10n: l10n,
                        bottomPadding: 240.h + bottomPad,
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fitness_center_rounded,
                                color: colors.textSecondary, size: 48.sp),
                            SizedBox(height: 16.h),
                            Text(
                              l10n.addExercise,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),

          // ── Bottom rest timer panel ──
          if (!_isPaused)
            Positioned(
              left: 5.w,
              right: 5.w,
              bottom: 0,
              child: _BottomPanel(
                session: session,
                notifier: notifier,
                elapsedSeconds: _elapsedSeconds,
                bottomPadding: bottomPad,
                l10n: l10n,
                onHowTo: () => _showHowToSheet(exercise),
                onPause: _togglePause,
              ),
            ),

          // ── Pause overlay ──
          if (_isPaused)
            _PauseOverlay(
              session: session,
              notifier: notifier,
              bottomPadding: bottomPad,
              l10n: l10n,
              onResume: _togglePause,
            ),
        ],
      ),
    );
  }

  void _showMenuSheet(BuildContext context, ActiveSessionState session,
      ActiveSessionNotifier notifier) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 16.h),
            ListTile(
              leading: Icon(Icons.add_rounded, color: colors.accent),
              title: Text(l10n.addExercise,
                  style: TextStyle(color: colors.textPrimary)),
              onTap: () async {
                Navigator.pop(context);
                final exerciseId =
                    await context.push<String>(AppRoutes.exerciseBrowser);
                if (exerciseId != null) {
                  await notifier.addExercise(exerciseId);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.close_rounded, color: colors.danger),
              title: Text('Discard workout',
                  style: TextStyle(color: colors.danger)),
              onTap: () {
                Navigator.pop(context);
                _showDiscardDialog(context, notifier);
              },
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  void _showDiscardDialog(
      BuildContext context, ActiveSessionNotifier notifier) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(l10n.cancel,
            style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Discard this workout?',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel,
                style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.discardSession();
              context.pop();
            },
            child: Text(l10n.delete,
                style: TextStyle(color: colors.danger)),
          ),
        ],
      ),
    );
  }

  /// Show a "How to" bottom sheet with numbered step-by-step instructions
  /// for the current exercise.
  Future<void> _showHowToSheet(ActiveExercise? exercise) async {
    if (exercise == null) return;

    final exerciseDao = ExerciseDao(ref.read(databaseProvider));
    final fullExercise =
        await exerciseDao.findByExerciseId(exercise.exerciseId);
    if (fullExercise == null || !mounted) return;

    final steps = _parseInstructions(fullExercise.instructions);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HowToSheet(
        exercise: fullExercise,
        steps: steps,
      ),
    );
  }

  static List<String> _parseInstructions(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    var cleaned = raw;
    if (cleaned.startsWith('[')) cleaned = cleaned.substring(1);
    if (cleaned.endsWith(']')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    final lines = cleaned
        .split(RegExp(r'["\n]'))
        .map((s) => s.trim().replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), ''))
        .where((s) => s.isNotEmpty && s != ',')
        .toList();
    return lines;
  }
}

// ═══════════════════════════════════════════════════════════════
// EXERCISE IMAGE AREA — top half, white bg, centered GIF
// ═══════════════════════════════════════════════════════════════

class _ExerciseImageArea extends StatelessWidget {
  final ActiveExercise? exercise;
  final VoidCallback onMenuTap;

  const _ExerciseImageArea({required this.exercise, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      height: 340.h,
      color: Colors.white,
      child: Stack(
        children: [
          // Exercise GIF
          if (exercise?.gifUrl != null)
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: topPad),
                child: CachedNetworkImage(
                  imageUrl: exercise!.gifUrl!,
                  width: 280.w,
                  height: 280.h,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  memCacheWidth: (280.w * MediaQuery.devicePixelRatioOf(context)).toInt(),
                  memCacheHeight: (280.h * MediaQuery.devicePixelRatioOf(context)).toInt(),
                  placeholder: (_, __) => const SizedBox.shrink(),
                  errorWidget: (_, __, ___) => Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.grey[400],
                    size: 60.sp,
                  ),
                ),
              ),
            )
          else
            Center(
              child: Icon(
                Icons.fitness_center_rounded,
                color: Colors.grey[400],
                size: 60.sp,
              ),
            ),

          // Close — liquid glass (opens menu/discard)
          Positioned(
            right: 22.w,
            top: topPad + 6.h,
            child: OcGlassBtn(
              type: OcGlassBtnType.close,
              size: 44,
              onTap: onMenuTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PROGRESS PILLS — one per exercise, current = accent
// ═══════════════════════════════════════════════════════════════

class _ProgressPills extends StatelessWidget {
  final int total;
  final int current;
  final ValueChanged<int> onTap;

  const _ProgressPills({
    required this.total,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (total == 0) return SizedBox(height: 12.h);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 8.h),
      child: Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                height: 5.h,
                margin: EdgeInsets.only(right: i < total - 1 ? 6.w : 0),
                decoration: BoxDecoration(
                  color:
                      i <= current ? colors.accent : colors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.5.r),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SETS TABLE — scrollable list of set rows
// ═══════════════════════════════════════════════════════════════

class _SetsTable extends StatelessWidget {
  final ActiveExercise exercise;
  final ActiveSessionNotifier notifier;
  final AppLocalizations l10n;
  final double bottomPadding;

  const _SetsTable({
    required this.exercise,
    required this.notifier,
    required this.l10n,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final unit = notifier.weightUnit;

    return ListView(
      padding: EdgeInsets.only(bottom: bottomPadding),
      children: [
        // Set rows — each row has inline labels: "1 Set  ⇅60 Kg  ⇅10 Reps  ✓"
        ...exercise.sets.asMap().entries.map((entry) {
          final s = entry.value;
          return Column(
            children: [
              _SetRow(
                set: s,
                notifier: notifier,
                unit: unit,
              ),
              // Divider after each row
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w),
                child: Container(
                  height: 1,
                  color: const Color(0xFF757575).withValues(alpha: 0.3),
                ),
              ),
            ],
          );
        }),

        SizedBox(height: 8.h),

        // Add set button
        Padding(
          padding: EdgeInsets.only(left: 33.w),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => notifier.addSet(),
              child: LiquidGlassButton(
                width: 28.w,
                height: 28.w,
                opacity: 0.15,
                radius: 14.r,
                child: Icon(Icons.add,
                    color: AppColors.of(context).textPrimary, size: 16.sp),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  final ActiveSet set;
  final ActiveSessionNotifier notifier;
  final String unit;

  const _SetRow({
    required this.set,
    required this.notifier,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final displayWeight = notifier.displayWeight(set.weight);

    return GestureDetector(
      onTap: set.isCompleted
          ? null
          : () => notifier.completeSet(set.localId),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 10.h),
        child: Row(
          children: [
            // Set number + "Set" label
            Text(
              '${set.setIndex + 1}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 4.w),
            Text(
              'Set',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            // Weight with ⇅ icon + "Kg" label
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.unfold_more,
                        color: colors.textPrimary, size: 16.sp),
                    InlineEditableField(
                      value: displayWeight,
                      suffix: '',
                      onChanged: (v) =>
                          notifier.updateSet(set.localId, weightStr: v),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      unit == 'lbs' ? 'Lbs' : 'Kg',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Reps with ⇅ icon + "Reps" label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.unfold_more,
                    color: colors.textPrimary, size: 16.sp),
                InlineEditableField(
                  value: set.reps?.toString() ?? '0',
                  allowDecimal: false,
                  onChanged: (v) =>
                      notifier.updateSet(set.localId, repsStr: v),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Reps',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(width: 12.w),
            // Checkmark
            Icon(
              Icons.check_rounded,
              size: 19.sp,
              color: set.isCompleted
                  ? const Color(0xFF00FF44)
                  : const Color(0xFF494747),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BOTTOM PANEL — rest timer, total time, action buttons
// ═══════════════════════════════════════════════════════════════

class _BottomPanel extends StatelessWidget {
  final ActiveSessionState session;
  final ActiveSessionNotifier notifier;
  final int elapsedSeconds;
  final double bottomPadding;
  final AppLocalizations l10n;
  final VoidCallback onPause;
  final VoidCallback onHowTo;

  const _BottomPanel({
    required this.session,
    required this.notifier,
    required this.elapsedSeconds,
    required this.bottomPadding,
    required this.l10n,
    required this.onPause,
    required this.onHowTo,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}m';

    return Container(
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(56.r)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 6.h),
          // Handle bar
          Container(
            width: 53.w,
            height: 5.h,
            decoration: BoxDecoration(
              color: colors.divider,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),

          SizedBox(height: 10.h),

          // Timer row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: SizedBox(
              height: 155.h,
              child: Stack(
                children: [
                  // Total time — top left
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          l10n.totalDuration,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          timeStr,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rest timer circle — centered
                  Center(
                    child: _RestTimerCircle(
                      timerService: notifier.restTimerService,
                      visible: session.showRestTimer,
                    ),
                  ),

                  // +15s button — right of circle
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => notifier.restTimerService.addTime(15),
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: colors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '+15s',
                            style: TextStyle(
                              color: colors.panelBackground,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 8.h),

          // Bottom action buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Hint — liquid glass
                OcGlassBtn(
                  type: OcGlassBtnType.hint,
                  size: 66,
                  onTap: onHowTo,
                ),

                // Skip / next arrow
                GestureDetector(
                  onTap: () {
                    if (session.currentExerciseIndex <
                        session.exercises.length - 1) {
                      notifier.selectExercise(
                          session.currentExerciseIndex + 1);
                    } else {
                      onPause(); // last exercise — go to pause for End Session
                    }
                  },
                  child: Icon(Icons.arrow_forward_rounded,
                      color: colors.textPrimary, size: 26.sp),
                ),

                // Pause button
                GestureDetector(
                  onTap: onPause,
                  child: Container(
                    width: 66.w,
                    height: 66.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3E2125),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.w,
                            height: 26.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF34852),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            width: 6.w,
                            height: 26.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF34852),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 12.h),
        ],
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════
// REST TIMER CIRCLE — circular progress with countdown
// ═══════════════════════════════════════════════════════════════

class _RestTimerCircle extends StatefulWidget {
  final RestTimerService timerService;
  final bool visible;

  const _RestTimerCircle({
    required this.timerService,
    required this.visible,
  });

  @override
  State<_RestTimerCircle> createState() => _RestTimerCircleState();
}

class _RestTimerCircleState extends State<_RestTimerCircle> {
  bool _showCheck = false;
  bool _wasVisible = false;

  @override
  void didUpdateWidget(covariant _RestTimerCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When rest timer just became visible → show checkmark first
    if (widget.visible && !_wasVisible) {
      setState(() => _showCheck = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showCheck = false);
      });
    }
    _wasVisible = widget.visible;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // ── Checkmark state — set just completed ──
    if (_showCheck) {
      return SizedBox(
        width: 150.w,
        height: 150.w,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2A3A1A),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.check_rounded,
              color: colors.accent,
              size: 60.sp,
            ),
          ),
        ),
      );
    }

    // ── Countdown state ──
    return StreamBuilder<int>(
      stream: widget.timerService.stream,
      initialData: widget.timerService.remaining,
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? 0;
        final progress = widget.timerService.progress;
        final minutes = remaining ~/ 60;
        final seconds = remaining % 60;
        final timeStr =
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        return SizedBox(
          width: 150.w,
          height: 150.w,
          child: CustomPaint(
            painter: _TimerRingPainter(
              progress: widget.visible ? progress : 0,
              strokeWidth: 12.w,
              accentColor: colors.accent,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rest time',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.visible ? timeStr : '--:--',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double progress; // 1.0 = full, 0.0 = empty
  final double strokeWidth;
  final Color accentColor;

  _TimerRingPainter({required this.progress, required this.strokeWidth, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0xFF2F3206)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (progress > 0) {
      final fgPaint = Paint()
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
    }
  }

  @override
  bool shouldRepaint(_TimerRingPainter old) => old.progress != progress || old.accentColor != accentColor;
}

// ═══════════════════════════════════════════════════════════════
// PAUSE OVERLAY — shown when user taps pause
// ═══════════════════════════════════════════════════════════════

class _PauseOverlay extends StatelessWidget {
  final ActiveSessionState session;
  final ActiveSessionNotifier notifier;
  final double bottomPadding;
  final AppLocalizations l10n;
  final VoidCallback onResume;

  const _PauseOverlay({
    required this.session,
    required this.notifier,
    required this.bottomPadding,
    required this.l10n,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Positioned(
      left: 5.w,
      right: 5.w,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(56.r)),
        ),
        padding: EdgeInsets.only(bottom: bottomPadding + 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),

            // Handle bar
            Container(
              width: 53.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),

            SizedBox(height: 14.h),

            // Rest timer circle
            StreamBuilder<int>(
              stream: notifier.restTimerService.stream,
              initialData: notifier.restTimerService.remaining,
              builder: (context, snapshot) {
                final remaining = snapshot.data ?? 0;
                final progress = notifier.restTimerService.progress;
                final minutes = remaining ~/ 60;
                final seconds = remaining % 60;
                final timeStr =
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

                return SizedBox(
                  width: 150.w,
                  height: 150.w,
                  child: CustomPaint(
                    painter: _TimerRingPainter(
                      progress: session.showRestTimer ? progress : 0,
                      strokeWidth: 12.w,
                      accentColor: colors.accent,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Remaining',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            session.showRestTimer ? timeStr : '--:--',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'You must rest after\nthis set',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 14.h),

            // End Session button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 22.w),
              child: GestureDetector(
                onTap: () async {
                  await notifier.finishSession();
                  if (context.mounted) context.pop();
                },
                child: Container(
                  width: double.infinity,
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E2125),
                    borderRadius: BorderRadius.circular(40.r),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            color: const Color(0xFFF34852), size: 26.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'End Session',
                          style: TextStyle(
                            color: const Color(0xFFF34852),
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 10.h),

            // Previous / Next segmented button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 22.w),
              child: Container(
                width: double.infinity,
                height: 80.h,
                decoration: BoxDecoration(
                  color: colors.cardElevated,
                  borderRadius: BorderRadius.circular(40.r),
                ),
                child: Row(
                  children: [
                    // Previous
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (session.currentExerciseIndex > 0) {
                            notifier.selectExercise(
                                session.currentExerciseIndex - 1);
                          }
                          onResume();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF353537),
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(40.r),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Previous',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Next
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (session.currentExerciseIndex <
                              session.exercises.length - 1) {
                            notifier.selectExercise(
                                session.currentExerciseIndex + 1);
                          }
                          onResume();
                        },
                        child: Center(
                          child: Text(
                            'Next',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 14.h),

            // Bottom action buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 22.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Hint — liquid glass
                  OcGlassBtn(
                    type: OcGlassBtnType.hint,
                    size: 66,
                  ),

                  // Resume / play button
                  GestureDetector(
                    onTap: onResume,
                    child: Container(
                      width: 66.w,
                      height: 66.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFF344F2D),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(Icons.play_arrow_rounded,
                            color: colors.accent, size: 34.sp),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HOW-TO SHEET — step-by-step exercise instructions
// ═══════════════════════════════════════════════════════════════

class _HowToSheet extends StatelessWidget {
  final Exercise exercise;
  final List<String> steps;

  const _HowToSheet({required this.exercise, required this.steps});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        final colors = AppColors.of(context);
        return Container(
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          children: [
            SizedBox(height: 8.h),
            // Handle bar
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 12.h),

            // Header: "How to" + exercise name + close
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  // Circular GIF thumbnail
                  if (exercise.gifUrl != null)
                    ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: exercise.gifUrl!,
                        width: 44.w,
                        height: 44.w,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 44.w,
                          height: 44.w,
                          color: colors.separator,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 44.w,
                          height: 44.w,
                          color: colors.separator,
                          child: Icon(Icons.fitness_center_rounded,
                              color: colors.textSecondary, size: 20.sp),
                        ),
                      ),
                    ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12.sp,
                          ),
                        ),
                        Text(
                          exercise.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: colors.cardElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: colors.textPrimary, size: 18.sp),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Steps list
            Expanded(
              child: steps.isEmpty
                  ? Center(
                      child: Text(
                        'No instructions available',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14.sp,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      itemCount: steps.length,
                      itemBuilder: (_, i) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Step number circle
                              Container(
                                width: 28.w,
                                height: 28.w,
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              // Step text
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 4.h),
                                  child: Text(
                                    steps[i],
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14.sp,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
      },
    );
  }
}
