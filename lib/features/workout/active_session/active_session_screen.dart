import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';
import 'package:my_gym_bro/features/workout/active_session/rest_timer_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/inline_editable_field.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';
import 'package:my_gym_bro/shared/widgets/oc_glass_btn.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {

  const ActiveSessionScreen({super.key, this.scheduleDayId});
  /// Optional schedule day ID to pre-load exercises from a schedule.
  final int? scheduleDayId;

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  Timer? _durationTimer;
  int _elapsedSeconds = 0;
  bool _isPaused = false;
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    WakelockPlus.disable();
    // Invalidate providers so the workout/home screens refresh after session ends
    if (_container != null) {
      _container!
        ..invalidate(muscleRecoveryProvider)
        ..invalidate(enrichedRecentSessionsProvider)
        ..invalidate(weeklyStatsProvider)
        ..invalidate(recentSessionsProvider)
        ..invalidate(consecutiveRestDaysProvider);
    }
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

    // Keep the rest-complete notification copy in sync with the user's
    // current locale and chosen notification tone. Cheap (two field
    // writes) so running it on every build is fine.
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final tone = notificationToneFromString(profile?.notificationTone);
    notifier.setRestNotificationStrings(
      restCompleteTitleForTone(tone, l10n),
      restCompleteBodyForTone(tone, l10n),
    );
    final restDays =
        ref.watch(consecutiveRestDaysProvider).valueOrNull ?? 0;
    notifier.setWorkoutReminderStrings(
      workoutReminderTitleForRestDays(tone, restDays),
      workoutReminderBodyForRestDays(tone, restDays),
    );
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
                onSwipeLeft: session.currentExerciseIndex < session.exercises.length - 1
                    ? () => notifier.selectExercise(session.currentExerciseIndex + 1)
                    : null,
                onSwipeRight: session.currentExerciseIndex > 0
                    ? () => notifier.selectExercise(session.currentExerciseIndex - 1)
                    : null,
              ),

              // Progress pills
              _ProgressPills(
                total: session.exercises.length,
                current: session.currentExerciseIndex,
                onTap: notifier.selectExercise,
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
    showModalBottomSheet<void>(
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
              leading: Icon(Icons.delete_outline_rounded, color: colors.danger),
              title: Text(l10n.removeExercise,
                  style: TextStyle(color: colors.danger)),
              onTap: () {
                Navigator.pop(context);
                notifier.removeCurrentExercise();
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(l10n.cancel,
            style: TextStyle(color: colors.textPrimary)),
        content: Text(
          l10n.discardWorkout,
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

    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HowToSheet(
        exercise: fullExercise,
        steps: steps,
      ),
    ));
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

  const _ExerciseImageArea({
    required this.exercise,
    required this.onMenuTap,
    this.onSwipeLeft,
    this.onSwipeRight,
  });
  final ActiveExercise? exercise;
  final VoidCallback onMenuTap;
  /// Called when the user swipes left (→ next exercise). Null when already at last.
  final VoidCallback? onSwipeLeft;
  /// Called when the user swipes right (→ previous exercise). Null when already at first.
  final VoidCallback? onSwipeRight;

  static const double _kVelocityThreshold = 200;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -_kVelocityThreshold) {
          onSwipeLeft?.call();
        } else if (v > _kVelocityThreshold) {
          onSwipeRight?.call();
        }
      },
      child: Container(
      width: double.infinity,
      height: 340.h,
      color: AppColors.of(context).white,
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
                    color: AppColors.of(context).textSecondary,
                    size: 60.sp,
                  ),
                ),
              ),
            )
          else
            Center(
              child: Icon(
                Icons.fitness_center_rounded,
                color: AppColors.of(context).textSecondary,
                size: 60.sp,
              ),
            ),

          // Menu — liquid glass (opens exercise menu)
          Positioned(
            right: 22.w,
            top: topPad + 6.h,
            child: LiquidGlassButton(
              width: 44.w,
              height: 44.w,
              radius: 22.r,
              onTap: onMenuTap,
              child: Icon(
                Icons.menu_rounded,
                size: 22.sp,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
        ],
      ),
    ), // Container — child of GestureDetector
    ); // GestureDetector
  }
}

// ═══════════════════════════════════════════════════════════════
// PROGRESS PILLS — one per exercise, current = accent
// ═══════════════════════════════════════════════════════════════

class _ProgressPills extends StatelessWidget {

  const _ProgressPills({
    required this.total,
    required this.current,
    required this.onTap,
  });
  final int total;
  final int current;
  final ValueChanged<int> onTap;

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

  const _SetsTable({
    required this.exercise,
    required this.notifier,
    required this.l10n,
    required this.bottomPadding,
  });
  final ActiveExercise exercise;
  final ActiveSessionNotifier notifier;
  final AppLocalizations l10n;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final unit = notifier.weightUnit;

    return ListView(
      padding: EdgeInsets.only(bottom: bottomPadding),
      children: [
        // Set rows — each row has inline labels: "1 Set  ⇅60 Kg  ⇅10 Reps  ✓"
        ...exercise.sets.map((s) {
          return Column(
            key: ValueKey('set_col_${s.localId}'),
            children: [
              Dismissible(
                key: ValueKey(s.localId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.only(right: 28.w),
                  color: AppColors.of(context).danger,
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppColors.of(context).white),
                ),
                confirmDismiss: (_) async {
                  return showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.of(context).card,
                      title: Text(
                        l10n.deleteSet,
                        style: TextStyle(
                            color: AppColors.of(context).textPrimary),
                      ),
                      content: Text(
                        l10n.deleteSetConfirm,
                        style: TextStyle(
                            color: AppColors.of(context).textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            l10n.cancel,
                            style: TextStyle(
                                color: AppColors.of(context).textSecondary),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            l10n.delete,
                            style: TextStyle(
                                color: AppColors.of(context).danger),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) => notifier.deleteSet(s.localId),
                child: _SetRow(
                  set: s,
                  exercise: exercise,
                  notifier: notifier,
                  unit: unit,
                ),
              ),
              // Divider after each row
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w),
                child: Container(
                  height: 1,
                  color: colors.separator.withValues(alpha: 0.3),
                ),
              ),
            ],
          );
        }),

        SizedBox(height: 8.h),

        // Add set button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTap: notifier.addSet,
                child: Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final glassSettings = OCLiquidGlassSettings(
                      blendPx: 3,
                      refractStrength: isDark ? 0.01 : 0.1,
                      distortFalloffPx: 13,
                      blurRadiusPx: isDark ? 4 : 5.5,
                      specAngle: 0.1,
                      specStrength: isDark ? -1 : -1.0,
                      specPower: 1,
                      specWidth: 3.5,
                      lightbandOffsetPx: 3,
                      lightbandWidthPx: 3.5,
                      lightbandStrength: isDark ? 0.6 : 0.4,
                      lightbandColor: isDark
                          ? const Color.fromARGB(255, 255, 255, 255)
                          : AppColors.of(context).white,
                    );
                    
                    final btnWidth = constraints.maxWidth;
                    final btnHeight = 36.h;

                    return SizedBox(
                      width: btnWidth,
                      height: btnHeight,
                      child: OCLiquidGlassGroup(
                        settings: glassSettings,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            OCLiquidGlass(
                              width: btnWidth,
                              height: btnHeight,
                              borderRadius: btnHeight / 2,
                              color: isDark
                                  ? AppColors.of(context).white.withValues(alpha: 0.06)
                                  : AppColors.of(context).black.withValues(alpha: 0.04),
                              shadow: BoxShadow(
                                color: AppColors.of(context).black.withValues(alpha: isDark ? 0.30 : 0.15),
                                blurRadius: 10.w,
                                offset: Offset(0, 4.h),
                              ),
                              child: const SizedBox.expand(),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: Text(
                                  l10n.addSet,
                                  style: TextStyle(
                                    color: AppColors.of(context).textPrimary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {

  const _SetRow({
    required this.set,
    required this.exercise,
    required this.notifier,
    required this.unit,
  });
  final ActiveSet set;
  final ActiveExercise exercise;
  final ActiveSessionNotifier notifier;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 10.h),
      child: exercise.isCardio
          ? _buildCardioRow(context, colors)
          : _buildStrengthRow(context, colors),
    );
  }

  Widget _buildStrengthRow(BuildContext context, AppColorsTheme colors) {
    return Row(
      children: [
        _setLabel(context, colors),
        // Weight
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.unfold_more, color: colors.textPrimary, size: 16.sp),
                InlineEditableField(
                  value: notifier.displayWeight(set.weight),
                  suffix: '',
                  onChanged: (v) => notifier.updateSet(set.localId, weightStr: v),
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
        // Reps
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.unfold_more, color: colors.textPrimary, size: 16.sp),
            InlineEditableField(
              value: set.reps?.toString() ?? '0',
              allowDecimal: false,
              onChanged: (v) => notifier.updateSet(set.localId, repsStr: v),
            ),
            SizedBox(width: 4.w),
            Text(
              AppLocalizations.of(context).reps,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(width: 12.w),
        _checkmark(colors),
      ],
    );
  }

  Widget _buildCardioRow(BuildContext context, AppColorsTheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary row: set label + Time + Distance + checkmark
        Row(
          children: [
            _setLabel(context, colors),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _cardioField(
                    colors: colors,
                    value: notifier.displayDuration(set.durationSeconds),
                    label: 'Min',
                    onChanged: (v) => notifier.updateSet(set.localId, durationStr: v),
                  ),
                  _cardioField(
                    colors: colors,
                    value: notifier.displayDouble(set.distance),
                    label: 'km',
                    onChanged: (v) => notifier.updateSet(set.localId, distanceStr: v),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            _checkmark(colors),
          ],
        ),
        // Secondary row: Speed + Incline
        Padding(
          padding: EdgeInsets.only(top: 4.h, left: 24.w),
          child: Row(
            children: [
              _cardioField(
                colors: colors,
                value: notifier.displayDouble(set.speed),
                label: 'km/h',
                onChanged: (v) => notifier.updateSet(set.localId, speedStr: v),
                secondary: true,
              ),
              SizedBox(width: 20.w),
              _cardioField(
                colors: colors,
                value: notifier.displayDouble(set.incline),
                label: '%',
                onChanged: (v) => notifier.updateSet(set.localId, inclineStr: v),
                secondary: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardioField({
    required AppColorsTheme colors,
    required String value,
    required String label,
    required ValueChanged<String> onChanged,
    bool secondary = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!secondary)
          Icon(Icons.unfold_more, color: colors.textPrimary, size: 16.sp),
        InlineEditableField(value: value, onChanged: onChanged),
        SizedBox(width: 3.w),
        Text(
          label,
          style: TextStyle(
            color: secondary ? colors.textSecondary : colors.textPrimary,
            fontSize: secondary ? 10.sp : 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _setLabel(BuildContext context, AppColorsTheme colors) {
    final (indicator, indicatorColor) = switch (set.setType) {
      SetType.warmUp   => ('W', const Color(0xFFFFA726)),
      SetType.failure  => ('F', const Color(0xFFEF5350)),
      SetType.dropset  => ('D', const Color(0xFF42A5F5)),
      SetType.normal   => ('${set.setIndex + 1}', colors.textPrimary),
    };

    return GestureDetector(
      onTap: () => _showSetTypeSheet(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20.w,
            child: Text(
              indicator,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: indicatorColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            AppLocalizations.of(context).setLabel,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 8.w),
        ],
      ),
    );
  }

  void _showSetTypeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SetTypeBottomSheet(set: set, notifier: notifier),
    );
  }

  Widget _checkmark(AppColorsTheme colors) {
    return Icon(
      Icons.check_rounded,
      size: 19.sp,
      color: set.isCompleted
          ? const Color(0xFF00FF44)
          : const Color(0xFF494747),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SET TYPE BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════

class _SetTypeBottomSheet extends StatelessWidget {

  const _SetTypeBottomSheet({required this.set, required this.notifier});
  final ActiveSet set;
  final ActiveSessionNotifier notifier;

  static const _warmUpColor  = Color(0xFFFFA726);
  static const _failureColor = Color(0xFFEF5350);
  static const _dropsetColor = Color(0xFF42A5F5);
  static const _removeColor  = Color(0xFFEF5350);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad + 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          SizedBox(height: 12.h),
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),
          // Title
          Text(
            l10n.selectSetType,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          Divider(color: colors.separator, height: 1),
          SizedBox(height: 10.h),
          // Options card
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              decoration: BoxDecoration(
                color: colors.panelBackground,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                children: [
                  _option(
                    context,
                    indicator: 'W',
                    color: _warmUpColor,
                    label: l10n.warmUpSet,
                    type: SetType.warmUp,
                  ),
                  _divider(colors),
                  _option(
                    context,
                    indicator: '${set.setIndex + 1}',
                    color: colors.textPrimary,
                    label: l10n.normalSet,
                    type: SetType.normal,
                  ),
                  _divider(colors),
                  _option(
                    context,
                    indicator: 'F',
                    color: _failureColor,
                    label: l10n.failureSet,
                    type: SetType.failure,
                  ),
                  _divider(colors),
                  _option(
                    context,
                    indicator: 'D',
                    color: _dropsetColor,
                    label: l10n.dropSet,
                    type: SetType.dropset,
                  ),
                  _divider(colors),
                  _removeOption(context, colors, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required String indicator,
    required Color color,
    required String label,
    required SetType type,
  }) {
    final colors = AppColors.of(context);
    final isActive = set.setType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () {
        notifier.updateSetType(set.localId, type);
        Navigator.pop(context);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
        child: Row(
          children: [
            SizedBox(
              width: 28.w,
              child: Text(
                indicator,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? color : colors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            // Info badge
            Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _removeOption(BuildContext context, AppColorsTheme colors, AppLocalizations l10n) {
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () {
        Navigator.pop(context);
        notifier.deleteSet(set.localId);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
        child: Row(
          children: [
            SizedBox(
              width: 28.w,
              child: Icon(Icons.close_rounded, color: _removeColor, size: 22.sp),
            ),
            SizedBox(width: 14.w),
            Text(
              l10n.removeSet,
              style: TextStyle(
                color: _removeColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppColorsTheme colors) =>
      Divider(color: colors.separator, height: 1, indent: 58.w);
}

// ═══════════════════════════════════════════════════════════════
// BOTTOM PANEL — rest timer, total time, action buttons
// ═══════════════════════════════════════════════════════════════

class _BottomPanel extends StatelessWidget {

  const _BottomPanel({
    required this.session,
    required this.notifier,
    required this.elapsedSeconds,
    required this.bottomPadding,
    required this.l10n,
    required this.onPause,
    required this.onHowTo,
  });
  final ActiveSessionState session;
  final ActiveSessionNotifier notifier;
  final int elapsedSeconds;
  final double bottomPadding;
  final AppLocalizations l10n;
  final VoidCallback onPause;
  final VoidCallback onHowTo;

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

                  // Rest timer circle — centered, tapping completes next set
                  Center(
                    child: GestureDetector(
                      onTap: () => notifier.completeNextSet(),
                      child: _RestTimerCircle(
                        timerService: notifier.restTimerService,
                        visible: session.showRestTimer,
                      ),
                    ),
                  ),

                  // +15s / -15s buttons — stacked right of circle
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
                  Positioned(
                    right: 0,
                    top: 48.h,
                    child: GestureDetector(
                      onTap: () => notifier.restTimerService.addTime(-15),
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: colors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '-15s',
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

  const _RestTimerCircle({
    required this.timerService,
    required this.visible,
  });
  final RestTimerService timerService;
  final bool visible;

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

        if (!widget.visible) {
          return SizedBox(
            width: 150.w,
            height: 150.w,
            child: CustomPaint(
              painter: _TimerRingPainter(
                progress: 0,
                strokeWidth: 12.w,
                accentColor: colors.accent,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: colors.accent, size: 36.sp),
                    SizedBox(height: 4.h),
                    Text(
                      AppLocalizations.of(context).done,
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).completeSet,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width: 150.w,
          height: 150.w,
          child: CustomPaint(
            painter: _TimerRingPainter(
              progress: progress,
              strokeWidth: 12.w,
              accentColor: colors.accent,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppLocalizations.of(context).restTime,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    timeStr,
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

  _TimerRingPainter({required this.progress, required this.strokeWidth, required this.accentColor});
  final double progress; // 1.0 = full, 0.0 = empty
  final double strokeWidth;
  final Color accentColor;

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

  const _PauseOverlay({
    required this.session,
    required this.notifier,
    required this.bottomPadding,
    required this.l10n,
    required this.onResume,
  });
  final ActiveSessionState session;
  final ActiveSessionNotifier notifier;
  final double bottomPadding;
  final AppLocalizations l10n;
  final VoidCallback onResume;

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
                            l10n.remaining,
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
                            l10n.restAfterSet,
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
                  final hasIncomplete = session.exercises.any(
                    (ex) => ex.sets.any((s) => !s.isCompleted),
                  );
                  if (hasIncomplete) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: colors.card,
                        title: Text(
                          l10n.unfinishedSets,
                          style: TextStyle(color: colors.textPrimary),
                        ),
                        content: Text(
                          l10n.unfinishedSetsMessage,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              l10n.cancel,
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(
                              l10n.confirm,
                              style: TextStyle(color: colors.danger),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                  }
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
                          l10n.endSession,
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
                              l10n.previousExercise,
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
                            l10n.nextExercise,
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
                  const OcGlassBtn(
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

  const _HowToSheet({required this.exercise, required this.steps});
  final Exercise exercise;
  final List<String> steps;

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
                          AppLocalizations.of(context).howTo,
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
                        AppLocalizations.of(context).noInstructions,
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
                                      color: AppColors.of(context).black,
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
