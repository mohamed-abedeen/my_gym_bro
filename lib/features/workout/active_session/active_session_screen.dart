import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/exercise_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/inline_editable_field.dart';
import 'package:my_gym_bro/shared/widgets/refractive_glass.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Per-set-type accent colors (matches the Figma redesign): completed bars
/// and check buttons take the full type color.
Color setTypeColor(SetType type) => switch (type) {
      SetType.normal => const Color(0xFF2BD958),
      SetType.warmUp => const Color(0xFF00D0E0),
      SetType.superset => const Color(0xFFE040D9),
      SetType.dropset => const Color(0xFFFF9F0A),
      SetType.failure => const Color(0xFFFF453A),
    };

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
  // Elapsed-seconds as a ValueNotifier so only the duration text rebuilds
  // every tick — not the whole _SetsTable / GIF / rest-timer subtree.
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);
  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If a session is already live (the user got here by tapping the
      // ongoing notification, or by returning to this screen from
      // backgrounded state) restoreOrResync just rebuilds the stale
      // notification against this isolate's handlers — it never calls
      // startSession, which would create a duplicate session row.
      // With no live session, first try to restore one the OS killed
      // (deep-link cold starts land here before the scaffold's restore
      // runs); only start fresh when there's truly nothing to resume.
      final notifier = ref.read(activeSessionProvider.notifier);
      unawaited(() async {
        final restoredOrLive = await notifier.restoreOrResync();
        if (!restoredOrLive) {
          await notifier.startSession(scheduleDayId: widget.scheduleDayId);
        }
      }());
    });
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Derive elapsed from the wall clock instead of counting ticks:
      // Dart timers don't fire while the app is suspended, so a tick
      // counter freezes in the background and re-entry restarts it at 0.
      final s = ref.read(activeSessionProvider);
      if (s.startedAt == null || s.isPaused) return;
      _elapsed.value = s.elapsedSeconds;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context);
    // Sync notification strings once per locale change. didChangeDependencies
    // fires on locale change because AppLocalizations is an InheritedWidget.
    _syncNotificationStrings();
  }

  void _syncNotificationStrings() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(activeSessionProvider.notifier);
    final profile = ref.read(userProfileProvider).valueOrNull;
    final tone = notificationToneFromString(profile?.notificationTone);
    final restDays =
        ref.read(consecutiveRestDaysProvider).valueOrNull ?? 0;
    notifier.setRestNotificationStrings(
      restCompleteTitleForTone(tone, l10n),
      restCompleteBodyForTone(tone, l10n),
    );
    notifier.setNotificationTone(tone);
    notifier.setWorkoutReminderStrings(
      workoutReminderTitleForRestDays(tone, restDays),
      workoutReminderBodyForRestDays(tone, restDays),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _elapsed.dispose();
    WakelockPlus.disable();
    // Invalidate providers so the workout/home screens refresh after session ends
    if (_container != null) {
      _container!
        ..invalidate(muscleRecoveryProvider)
        ..invalidate(enrichedRecentSessionsProvider)
        ..invalidate(weeklyStatsProvider)
        ..invalidate(lifetimeStatsProvider)
        ..invalidate(activityStatsProvider)
        ..invalidate(recentSessionsProvider)
        ..invalidate(consecutiveRestDaysProvider);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(activeSessionProvider);
    final notifier = ref.read(activeSessionProvider.notifier);
    final exercise = session.currentExercise;

    // Re-sync notification strings only when the underlying values change.
    // (Locale changes flow through didChangeDependencies instead.)
    ref.listen(userProfileProvider, (_, __) => _syncNotificationStrings());
    ref.listen(
      consecutiveRestDaysProvider,
      (_, __) => _syncNotificationStrings(),
    );

    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Main content ──
          Column(
            children: [
              // Exercise image card
              _ExerciseImageArea(
                exercise: exercise,
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

              SizedBox(height: 4.h),

              // Title row: exercise name + rest timer + menu
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise?.name ?? l10n.addExercise,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    GestureDetector(
                      onTap: _showRestSheet,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.alarm_rounded,
                        color: colors.textPrimary,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    GestureDetector(
                      onTap: () => _showMenuSheet(context, session, notifier),
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: colors.textPrimary,
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10.h),

              // Sets list
              Expanded(
                child: exercise != null
                    ? _SetsTable(
                        exercise: exercise,
                        notifier: notifier,
                        l10n: l10n,
                        bottomPadding: 160.h + bottomPad,
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

          // ── Top stats capsule — floats over the white image area ──
          Positioned(
            left: 20.w,
            right: 20.w,
            top: topPad + 8.h,
            child: _TopStatsCapsule(
              session: session,
              notifier: notifier,
              elapsed: _elapsed,
              l10n: l10n,
              gender: ref.watch(anatomyGenderProvider),
              skinPath: ref.watch(activeSkinPathProvider),
            ),
          ),

          // ── Rest countdown pill — floats above the bottom actions ──
          if (session.showRestTimer)
            Positioned(
              left: 20.w,
              right: 20.w,
              bottom: bottomPad + 80.h,
              child: _RestPill(notifier: notifier, onTap: _showRestSheet),
            ),

          // ── Finish / Discard ──
          Positioned(
            left: 20.w,
            right: 20.w,
            bottom: bottomPad + 12.h,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _finish,
                    child: Container(
                      height: 56.h,
                      decoration: BoxDecoration(
                        color: colors.cardElevated,
                        borderRadius: BorderRadius.circular(28.r),
                      ),
                      child: Center(
                        child: Text(
                          l10n.finish,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: GestureDetector(
                    onTap: _discard,
                    child: Container(
                      height: 56.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E1418),
                        borderRadius: BorderRadius.circular(28.r),
                      ),
                      child: Center(
                        child: Text(
                          l10n.discard,
                          style: TextStyle(
                            color: const Color(0xFFFF453A),
                            fontSize: 17.sp,
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
        ],
      ),
    );
  }

  Future<void> _finish() async {
    final session = ref.read(activeSessionProvider);
    final notifier = ref.read(activeSessionProvider.notifier);
    if (session.isFinishing || session.sessionId == null) return;
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

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
    if (mounted) context.pop();
  }

  Future<void> _discard() async {
    final notifier = ref.read(activeSessionProvider.notifier);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          l10n.discard,
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          l10n.discardWorkoutConfirm,
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
              l10n.discard,
              style: TextStyle(color: colors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await notifier.discardSession();
    if (mounted) context.pop();
  }

  void _showRestSheet() {
    final notifier = ref.read(activeSessionProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RestSheet(notifier: notifier),
    );
  }

  void _showMenuSheet(BuildContext context, ActiveSessionState session,
      ActiveSessionNotifier notifier) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final exercise = session.currentExercise;
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
            if (exercise != null)
              ListTile(
                leading: Icon(Icons.help_outline_rounded,
                    color: colors.textPrimary),
                title: Text(l10n.howTo,
                    style: TextStyle(color: colors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _showHowToSheet(exercise);
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
// TOP STATS CAPSULE — Time / Sets / Volume + worked muscles
// ═══════════════════════════════════════════════════════════════

class _TopStatsCapsule extends StatelessWidget {

  const _TopStatsCapsule({
    required this.session,
    required this.notifier,
    required this.elapsed,
    required this.l10n,
    required this.gender,
    required this.skinPath,
  });
  final ActiveSessionState session;
  final ActiveSessionNotifier notifier;
  final ValueNotifier<int> elapsed;
  final AppLocalizations l10n;
  final AnatomyGender gender;
  final String skinPath;

  static const double _kLbsPerKg = 2.20462;

  @override
  Widget build(BuildContext context) {
    final isLbs = notifier.weightUnit == 'lbs';
    final vol = isLbs ? session.totalVolume * _kLbsPerKg : session.totalVolume;
    final paused = session.isPaused;

    // Muscle groups worked in this session, shown "just trained" (red).
    final groups = <String>{
      for (final ex in session.exercises)
        if (ex.muscleGroup != null && !ex.isCardio) ex.muscleGroup!,
    };
    final muscleStates = [
      for (final g in groups)
        MuscleStateInfo(
          muscleGroup: g,
          state: MuscleState.recovering,
          recoveryPercent: 0,
        ),
    ];

    return Container(
      height: 54.h,
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14.w,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time — tap to pause/resume the session clock.
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (paused) {
                notifier.resume();
              } else {
                notifier.pause();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: _StatColumn(
              label: l10n.time,
              value: ValueListenableBuilder<int>(
                valueListenable: elapsed,
                builder: (_, seconds, __) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmt(seconds),
                      style: _valueStyle,
                    ),
                    SizedBox(width: 3.w),
                    Icon(
                      paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: paused
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.55),
                      size: 12.sp,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _StatColumn(
            label: l10n.sets,
            value: Text('${session.totalCompletedSets}', style: _valueStyle),
          ),
          _StatColumn(
            label: l10n.volume,
            value: Text(
              '${vol.round()} ${isLbs ? 'lbs' : 'kg'}',
              style: _valueStyle,
            ),
          ),
          AnatomyBody(
            muscleStates: muscleStates,
            height: 42.h,
            gender: gender,
            basePngPath: skinPath,
          ),
        ],
      ),
    );
  }

  static String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}m';
  }

  TextStyle get _valueStyle => TextStyle(
        color: Colors.white,
        fontSize: 13.sp,
        fontWeight: FontWeight.w800,
      );
}

class _StatColumn extends StatelessWidget {

  const _StatColumn({required this.label, required this.value});
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 8.5.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 2.h),
        value,
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EXERCISE IMAGE AREA — top, white bg, centered GIF, rounded bottom
// ═══════════════════════════════════════════════════════════════

class _ExerciseImageArea extends StatelessWidget {

  const _ExerciseImageArea({
    required this.exercise,
    this.onSwipeLeft,
    this.onSwipeRight,
  });
  final ActiveExercise? exercise;
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
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36.r)),
        child: Container(
          width: double.infinity,
          height: 330.h,
          color: AppColors.of(context).white,
          child: exercise?.gifUrl != null
              ? Center(
                  child: Padding(
                    // Keep the GIF clear of the floating stats capsule.
                    padding: EdgeInsets.only(top: topPad + 30.h),
                    child: CachedNetworkImage(
                      cacheManager: ExerciseGifCache.instance,
                      imageUrl: exercise!.gifUrl!,
                      width: 260.w,
                      height: 250.h,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      memCacheWidth: (260.w * MediaQuery.devicePixelRatioOf(context)).toInt(),
                      memCacheHeight: (250.h * MediaQuery.devicePixelRatioOf(context)).toInt(),
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.fitness_center_rounded,
                        color: AppColors.of(context).textSecondary,
                        size: 60.sp,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.of(context).textSecondary,
                    size: 60.sp,
                  ),
                ),
        ),
      ),
    );
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
// SETS TABLE — scrollable list of glassy set-row pills
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
    final sets = exercise.sets;
    // ListView.builder so only visible rows build (and rebuild) — important
    // for long workouts where the old `ListView(children: ...map)` rebuilt
    // every row on any setState in the parent.
    return ListView.builder(
      padding: EdgeInsets.only(bottom: bottomPadding),
      itemCount: sets.length + 1, // +1 for the trailing Add Set button
      itemBuilder: (context, i) {
        if (i == sets.length) {
          return Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: _buildAddSetButton(context),
          );
        }
        final s = sets[i];
        return _SetRow(
          key: ValueKey('set_row_${s.localId}'),
          set: s,
          exercise: exercise,
          notifier: notifier,
          unit: notifier.weightUnit,
        );
      },
    );
  }

  Widget _buildAddSetButton(BuildContext context) {
    return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onTap: notifier.addSet,
                child: Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final btnWidth = constraints.maxWidth;
                    final btnHeight = 36.h;

                    return SizedBox(
                      width: btnWidth,
                      height: btnHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          RefractiveGlass(
                            width: btnWidth,
                            height: btnHeight,
                            radius: btnHeight / 2,
                            shadow: GlassDecoration.shadow(isDark: isDark),
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
                    );
                  },
                ),
              );
            },
          ),
        );
  }
}

// ═══════════════════════════════════════════════════════════════
// SET ROW — glassy pill + check button; completed rows take the
// set-type color. Drag the check button left to arm delete.
// ═══════════════════════════════════════════════════════════════

enum _SetMenuAction { normal, warmUp, superset, dropset, failure, remove }

class _SetRow extends StatefulWidget {

  const _SetRow({
    required this.set,
    required this.exercise,
    required this.notifier,
    required this.unit,
    super.key,
  });
  final ActiveSet set;
  final ActiveExercise exercise;
  final ActiveSessionNotifier notifier;
  final String unit;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  /// Armed = the row shows the red "Press To Delete" confirm bar.
  bool _armed = false;
  double _dragX = 0;
  Timer? _disarmTimer;

  static const double _kArmThreshold = -45;

  @override
  void dispose() {
    _disarmTimer?.cancel();
    super.dispose();
  }

  void _arm() {
    HapticFeedback.mediumImpact();
    setState(() {
      _armed = true;
      _dragX = 0;
    });
    // Auto-disarm so a forgotten row doesn't stay in delete mode.
    _disarmTimer?.cancel();
    _disarmTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _armed = false);
    });
  }

  void _disarm() {
    _disarmTimer?.cancel();
    setState(() => _armed = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final barHeight = widget.exercise.isCardio ? 76.h : 46.h;

    if (_armed) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h),
        child: _deleteBar(l10n, barHeight),
      );
    }

    final type = widget.set.setType;
    final typeColor = setTypeColor(type);
    final completed = widget.set.isCompleted;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _bar(colors, l10n, type, typeColor, completed, barHeight)),
          SizedBox(width: 8.w),
          _checkButton(colors, typeColor, completed, barHeight),
        ],
      ),
    );
  }

  // ── The pill bar ──

  Widget _bar(AppColorsTheme colors, AppLocalizations l10n, SetType type,
      Color typeColor, bool completed, double barHeight) {
    final content = widget.exercise.isCardio
        ? _cardioContent(colors, l10n, type, typeColor, completed)
        : _strengthContent(colors, l10n, type, typeColor, completed);

    if (completed) {
      return Container(
        height: barHeight,
        decoration: BoxDecoration(
          color: typeColor,
          borderRadius: BorderRadius.circular(barHeight / 2),
        ),
        child: content,
      );
    }
    // Frosted glass pill for pending sets.
    return GlassSurface(
      height: barHeight,
      radius: barHeight / 2,
      blurSigma: AppGlass.blurButton,
      child: content,
    );
  }

  // Text colors: dark-on-color when completed, theme colors otherwise.
  Color _primaryText(AppColorsTheme colors, bool completed) =>
      completed ? Colors.black.withValues(alpha: 0.85) : colors.textPrimary;
  Color _secondaryText(AppColorsTheme colors, bool completed) =>
      completed ? Colors.black.withValues(alpha: 0.55) : colors.textSecondary;

  Widget _strengthContent(AppColorsTheme colors, AppLocalizations l10n,
      SetType type, Color typeColor, bool completed) {
    final primary = _primaryText(colors, completed);
    final secondary = _secondaryText(colors, completed);

    return Row(
      children: [
        _setLabel(colors, l10n, type, typeColor, completed),
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.unfold_more, color: primary, size: 14.sp),
                InlineEditableField(
                  value: widget.notifier.displayWeight(widget.set.weight),
                  onChanged: (v) =>
                      widget.notifier.updateSet(widget.set.localId, weightStr: v),
                  style: _fieldStyle(primary),
                  padding: _fieldPadding,
                ),
                Text(
                  widget.unit == 'lbs' ? 'Lbs' : 'Kg',
                  style: TextStyle(
                    color: secondary,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InlineEditableField(
              value: widget.set.reps?.toString() ?? '0',
              allowDecimal: false,
              onChanged: (v) =>
                  widget.notifier.updateSet(widget.set.localId, repsStr: v),
              style: _fieldStyle(primary),
              padding: _fieldPadding,
            ),
            Text(
              l10n.reps,
              style: TextStyle(
                color: secondary,
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(width: 16.w),
      ],
    );
  }

  Widget _cardioContent(AppColorsTheme colors, AppLocalizations l10n,
      SetType type, Color typeColor, bool completed) {
    final primary = _primaryText(colors, completed);
    final secondary = _secondaryText(colors, completed);

    // Compact tap targets so two rows fit inside the cardio bar.
    final compact = BoxConstraints(minWidth: 32.w, minHeight: 30.h);
    Widget field(String value, String label, ValueChanged<String> onChanged) =>
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InlineEditableField(
              value: value,
              onChanged: onChanged,
              style: _fieldStyle(primary),
              padding: _fieldPadding,
              constraints: compact,
            ),
            Text(
              label,
              style: TextStyle(
                color: secondary,
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            _setLabel(colors, l10n, type, typeColor, completed),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  field(
                    widget.notifier.displayDuration(widget.set.durationSeconds),
                    'Min',
                    (v) => widget.notifier
                        .updateSet(widget.set.localId, durationStr: v),
                  ),
                  field(
                    widget.notifier.displayDouble(widget.set.distance),
                    'km',
                    (v) => widget.notifier
                        .updateSet(widget.set.localId, distanceStr: v),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w),
          ],
        ),
        Row(
          children: [
            SizedBox(width: 56.w),
            field(
              widget.notifier.displayDouble(widget.set.speed),
              'km/h',
              (v) => widget.notifier.updateSet(widget.set.localId, speedStr: v),
            ),
            SizedBox(width: 16.w),
            field(
              widget.notifier.displayDouble(widget.set.incline),
              '%',
              (v) =>
                  widget.notifier.updateSet(widget.set.localId, inclineStr: v),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle _fieldStyle(Color color) => TextStyle(
        color: color,
        fontSize: 14.sp,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature('ss15')],
      );

  EdgeInsetsGeometry get _fieldPadding =>
      EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h);

  /// "n Set" / "W Set" — tap opens the set-type menu anchored to it.
  Widget _setLabel(AppColorsTheme colors, AppLocalizations l10n, SetType type,
      Color typeColor, bool completed) {
    final indicator = switch (type) {
      SetType.normal => '${widget.set.setIndex + 1}',
      SetType.warmUp => 'W',
      SetType.superset => 'S',
      SetType.dropset => 'D',
      SetType.failure => 'F',
    };
    final indicatorColor = completed
        ? Colors.black.withValues(alpha: 0.85)
        : (type == SetType.normal ? colors.textPrimary : typeColor);

    return Builder(
      builder: (anchorCtx) => GestureDetector(
        onTap: () => _showTypeMenu(anchorCtx),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40.h,
          padding: EdgeInsets.only(left: 16.w, right: 6.w),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                indicator,
                style: TextStyle(
                  color: indicatorColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 3.w),
              Text(
                l10n.setLabel,
                style: TextStyle(
                  color: _secondaryText(colors, completed),
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Set type context menu ──

  Future<void> _showTypeMenu(BuildContext anchorCtx) async {
    final l10n = AppLocalizations.of(context);
    final box = anchorCtx.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + box.size.height + 2,
      overlay.size.width - origin.dx - 220.w,
      0,
    );

    PopupMenuItem<_SetMenuAction> item({
      required _SetMenuAction action,
      required Widget indicator,
      required String label,
      required Color color,
    }) =>
        PopupMenuItem<_SetMenuAction>(
          value: action,
          height: 40.h,
          child: Row(
            children: [
              SizedBox(width: 22.w, child: Center(child: indicator)),
              SizedBox(width: 10.w),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    Text glyph(String s, Color c) => Text(
          s,
          style: TextStyle(
            color: c,
            fontSize: 13.sp,
            fontWeight: FontWeight.w800,
          ),
        );

    final white = Colors.white.withValues(alpha: 0.92);
    const danger = Color(0xFFFF453A);

    final action = await showMenu<_SetMenuAction>(
      context: context,
      position: position,
      color: const Color(0xF2202022),
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      constraints: BoxConstraints(minWidth: 185.w),
      items: [
        item(
          action: _SetMenuAction.normal,
          indicator: glyph('${widget.set.setIndex + 1}', white),
          label: l10n.normalSet,
          color: white,
        ),
        item(
          action: _SetMenuAction.warmUp,
          indicator: glyph('W', setTypeColor(SetType.warmUp)),
          label: l10n.warmUpSet,
          color: setTypeColor(SetType.warmUp),
        ),
        item(
          action: _SetMenuAction.superset,
          indicator: glyph('S', setTypeColor(SetType.superset)),
          label: l10n.superSet,
          color: setTypeColor(SetType.superset),
        ),
        item(
          action: _SetMenuAction.dropset,
          indicator: glyph('D', setTypeColor(SetType.dropset)),
          label: l10n.dropSet,
          color: setTypeColor(SetType.dropset),
        ),
        item(
          action: _SetMenuAction.failure,
          indicator: glyph('F', setTypeColor(SetType.failure)),
          label: l10n.failureSet,
          color: setTypeColor(SetType.failure),
        ),
        item(
          action: _SetMenuAction.remove,
          indicator:
              Icon(Icons.delete_outline_rounded, color: danger, size: 15.sp),
          label: l10n.removeSet,
          color: danger,
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _SetMenuAction.normal:
        await widget.notifier.updateSetType(widget.set.localId, SetType.normal);
      case _SetMenuAction.warmUp:
        await widget.notifier.updateSetType(widget.set.localId, SetType.warmUp);
      case _SetMenuAction.superset:
        await widget.notifier
            .updateSetType(widget.set.localId, SetType.superset);
      case _SetMenuAction.dropset:
        await widget.notifier
            .updateSetType(widget.set.localId, SetType.dropset);
      case _SetMenuAction.failure:
        await widget.notifier
            .updateSetType(widget.set.localId, SetType.failure);
      case _SetMenuAction.remove:
        _arm(); // same press-to-confirm bar as the drag gesture
    }
  }

  // ── Check button (tap = complete/uncomplete, drag left = arm delete) ──

  Widget _checkButton(AppColorsTheme colors, Color typeColor, bool completed,
      double barHeight) {
    final button = completed
        ? Container(
            width: 58.w,
            height: barHeight,
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(barHeight / 2),
            ),
            child: Center(
              child: Icon(Icons.check_rounded, color: Colors.white, size: 24.sp),
            ),
          )
        : GlassSurface(
            width: 58.w,
            height: barHeight,
            radius: barHeight / 2,
            blurSigma: AppGlass.blurButton,
            child: Center(
              child: Icon(
                Icons.check_rounded,
                color: colors.textPrimary.withValues(alpha: 0.8),
                size: 24.sp,
              ),
            ),
          );

    return GestureDetector(
      onTap: () {
        if (completed) {
          HapticFeedback.selectionClick();
          widget.notifier.uncompleteSet(widget.set.localId);
        } else {
          widget.notifier.completeSet(widget.set.localId);
        }
      },
      onHorizontalDragUpdate: (d) => setState(
        () => _dragX = (_dragX + d.delta.dx).clamp(-80.0, 0.0),
      ),
      onHorizontalDragEnd: (_) {
        if (_dragX < _kArmThreshold) {
          _arm();
        } else {
          setState(() => _dragX = 0);
        }
      },
      onHorizontalDragCancel: () => setState(() => _dragX = 0),
      child: Transform.translate(
        offset: Offset(_dragX, 0),
        child: button,
      ),
    );
  }

  // ── Red confirm-delete bar ──

  Widget _deleteBar(AppLocalizations l10n, double barHeight) {
    return Container(
      height: barHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7A1215), Color(0xFF45090C)],
        ),
        borderRadius: BorderRadius.circular(barHeight / 2),
      ),
      child: Row(
        children: [
          // X — cancel.
          GestureDetector(
            onTap: _disarm,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Container(
                width: barHeight - 8.w,
                height: barHeight - 8.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF9B1B1F),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.close_rounded,
                      color: Colors.white, size: 20.sp),
                ),
              ),
            ),
          ),
          // Press the text to confirm the delete.
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                widget.notifier.deleteSet(widget.set.localId);
              },
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Text(
                  l10n.pressToDelete,
                  style: TextStyle(
                    color: const Color(0xFFFF6B6B),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
          // Balance the X circle so the text is optically centered.
          SizedBox(width: barHeight - 4.w),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REST PILL — compact countdown floating above the bottom actions
// ═══════════════════════════════════════════════════════════════

class _RestPill extends StatelessWidget {

  const _RestPill({required this.notifier, required this.onTap});
  final ActiveSessionNotifier notifier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        height: 50.h,
        radius: 25.r,
        tint: colors.panelBackground.withValues(alpha: 0.7),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            Icon(Icons.alarm_rounded, color: colors.accent, size: 18.sp),
            SizedBox(width: 8.w),
            StreamBuilder<int>(
              stream: notifier.restTimerService.stream,
              initialData: notifier.restTimerService.remaining,
              builder: (_, snapshot) {
                final remaining = snapshot.data ?? 0;
                final m = remaining ~/ 60;
                final s = remaining % 60;
                return Text(
                  '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature('ss15')],
                  ),
                );
              },
            ),
            const Spacer(),
            _chip(context, '+15s', () => notifier.restTimerService.addTime(15)),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: notifier.hideRestTimer,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.close_rounded,
                      color: colors.textPrimary, size: 16.sp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback onTap) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// REST SHEET — full rest-timer ring with ±15s / skip
// ═══════════════════════════════════════════════════════════════

class _RestSheet extends ConsumerWidget {

  const _RestSheet({required this.notifier});
  final ActiveSessionNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final running =
        ref.watch(activeSessionProvider.select((s) => s.showRestTimer));

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 12.h),
      child: SafeArea(
        top: false,
        child: GlassSurface(
          radius: 32.r,
          tint: colors.panelBackground.withValues(alpha: 0.78),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 18.h),
              StreamBuilder<int>(
                stream: notifier.restTimerService.stream,
                initialData: notifier.restTimerService.remaining,
                builder: (_, snapshot) {
                  final remaining = snapshot.data ?? 0;
                  final m = remaining ~/ 60;
                  final s = remaining % 60;
                  final timeStr = running
                      ? '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
                      : '--:--';
                  return SizedBox(
                    width: 150.w,
                    height: 150.w,
                    child: CustomPaint(
                      painter: _TimerRingPainter(
                        progress:
                            running ? notifier.restTimerService.progress : 0,
                        strokeWidth: 12.w,
                        accentColor: colors.accent,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.restTime,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 30.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 18.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chip(context, '-15s',
                      running ? () => notifier.restTimerService.addTime(-15) : null),
                  SizedBox(width: 12.w),
                  _chip(context, '+15s',
                      running ? () => notifier.restTimerService.addTime(15) : null),
                  SizedBox(width: 12.w),
                  _chip(
                    context,
                    l10n.done,
                    running
                        ? () {
                            notifier.hideRestTimer();
                            Navigator.of(context).pop();
                          }
                        : null,
                    accent: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback? onTap,
      {bool accent = false}) {
    final colors = AppColors.of(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: accent
              ? colors.accent.withValues(alpha: enabled ? 0.16 : 0.06)
              : Colors.white.withValues(alpha: enabled ? 0.12 : 0.05),
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: accent
                ? colors.accent.withValues(alpha: enabled ? 1 : 0.4)
                : colors.textPrimary.withValues(alpha: enabled ? 1 : 0.4),
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
                        cacheManager: ExerciseGifCache.instance,
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
