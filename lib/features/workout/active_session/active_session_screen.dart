import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/cupertino.dart' show CupertinoPicker;
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
import 'package:my_gym_bro/features/exercises/exercise_detail_screen.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';
import 'package:my_gym_bro/features/workout/active_session/pr_banner.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_helpers.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/inline_editable_field.dart';
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

  /// Tapping the mini body in the top bar swaps the GIF card for the
  /// anatomy recovery panel; tapping again (or the panel) swaps back.
  bool _showAnatomy = false;

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
    final restDays = ref.read(consecutiveRestDaysProvider).valueOrNull ?? 0;
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

    // "NEW PR!" banner — fires when completeSet detects a new record.
    ref.listen(activeSessionProvider.select((s) => s.prEvent), (prev, next) {
      if (next == null || identical(next, prev)) return;
      final isLbs = notifier.weightUnit == 'lbs';
      final w = isLbs ? next.weightKg * 2.20462 : next.weightKg;
      final wText = w % 1 == 0 ? w.toStringAsFixed(0) : w.toStringAsFixed(1);
      showPrBanner(
        context,
        title: l10n.newPrTitle,
        body:
            '${next.exerciseName} · $wText '
            '${isLbs ? 'lbs' : 'kg'} × ${next.reps}',
      );
    });

    // Re-sync notification strings only when the underlying values change.
    // (Locale changes flow through didChangeDependencies instead.)
    ref.listen(userProfileProvider, (_, __) => _syncNotificationStrings());
    ref.listen(
      consecutiveRestDaysProvider,
      (_, __) => _syncNotificationStrings(),
    );

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // ── Main content — horizontal swipe anywhere switches exercise
          // (set rows absorb their own horizontal drags, see _SetRow) ──
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleExerciseSwipe,
            child: Column(
              children: [
                // Exercise image card
                _ExerciseImageArea(
                  exercise: exercise,
                  onTap: () => _openExerciseDetail(exercise),
                  onSwipeLeft:
                      session.currentExerciseIndex <
                          session.exercises.length - 1
                      ? () => notifier.selectExercise(
                          session.currentExerciseIndex + 1,
                        )
                      : null,
                  onSwipeRight: session.currentExerciseIndex > 0
                      ? () => notifier.selectExercise(
                          session.currentExerciseIndex - 1,
                        )
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
                      Semantics(
                        button: true,
                        label: l10n.restTimer,
                        child: GestureDetector(
                          // Live countdown sheet while resting, duration picker
                          // otherwise (the floating rest pill is gone).
                          onTap: session.showRestTimer
                              ? _showRestSheet
                              : _showRestPickerSheet,
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            Icons.alarm_rounded,
                            color: colors.textPrimary,
                            size: 22.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      // Builder so the menu can anchor to this icon's position.
                      Builder(
                        builder: (anchorCtx) => Semantics(
                          button: true,
                          label: l10n.moreOptions,
                          child: GestureDetector(
                            onTap: () => _showExerciseMenu(anchorCtx),
                            behavior: HitTestBehavior.opaque,
                            child: Icon(
                              Icons.more_vert_rounded,
                              color: colors.textPrimary,
                              size: 22.sp,
                            ),
                          ),
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
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fitness_center_rounded,
                                color: colors.textSecondary,
                                size: 48.sp,
                              ),
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
          ),

          // ── Anatomy island — Dynamic-Island-style dark glass card that
          // expands down from the top capsule when the mini body is tapped ──
          if (_showAnatomy)
            Positioned(
              left: 14.w,
              right: 14.w,
              top: 4.h,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (_, t, child) => Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * t,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                ),
                child: _AnatomyPanel(
                  session: session,
                  onTap: () => setState(() => _showAnatomy = false),
                ),
              ),
            ),

          // ── Top stats capsule — sits at the very top so the camera
          // notch / Dynamic Island lands in the gap between Sets & Volume ──
          Positioned(
            left: 20.w,
            right: 20.w,
            top: 8.h,
            child: _TopStatsCapsule(
              session: session,
              notifier: notifier,
              elapsed: _elapsed,
              l10n: l10n,
              gender: ref.watch(anatomyGenderProvider),
              skinPath: ref.watch(activeSkinPathProvider),
              onBodyTap: () => setState(() => _showAnatomy = !_showAnatomy),
              bodyHidden: _showAnatomy,
            ),
          ),

          // ── Finish / Discard + swipe-up actions drawer handle ──
          Positioned(
            left: 20.w,
            right: 20.w,
            bottom: bottomPad + 12.h,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -200) {
                  _showActionsSheet();
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle — swipe up (or tap) to open the drawer.
                  // Labeled: it's the only route to Add/Edit Exercises for
                  // screen-reader users (the swipe gesture is invisible to them).
                  Semantics(
                    button: true,
                    label: l10n.moreOptions,
                    child: GestureDetector(
                      onTap: _showActionsSheet,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 40.w,
                          vertical: 6.h,
                        ),
                        child: Container(
                          width: 48.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: colors.textSecondary.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  // Frosted capsule behind the pills — matches the Figma mock.
                  GlassSurface(
                    radius: 34.r,
                    padding: EdgeInsets.all(6.w),
                    child: _finishDiscardRow(colors, l10n),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Finish + Discard pill row — shown at the bottom of the screen and again
  /// inside the swipe-up actions drawer. When shown in the drawer, pass the
  /// sheet's [sheetCtx] so it closes before finish/discard runs — otherwise
  /// the screen-level `context.pop()` would pop the sheet, not the screen.
  Widget _finishDiscardRow(
    AppColorsTheme colors,
    AppLocalizations l10n, {
    BuildContext? sheetCtx,
  }) {
    return Row(
      children: [
        Expanded(
          // button: true only — the visible Text supplies the label.
          child: Semantics(
            button: true,
            child: GestureDetector(
              onTap: () {
                if (sheetCtx != null) Navigator.pop(sheetCtx);
                unawaited(_finish());
              },
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
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Semantics(
            button: true,
            child: GestureDetector(
              onTap: () {
                if (sheetCtx != null) Navigator.pop(sheetCtx);
                unawaited(_discard());
              },
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
        ),
      ],
    );
  }

  Future<void> _finish() async {
    final session = ref.read(activeSessionProvider);
    final notifier = ref.read(activeSessionProvider.notifier);
    if (session.isFinishing || session.sessionId == null) return;
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    // Always confirm — the Finish/Discard row sits at the bottom of the screen
    // and again in the swipe-up drawer, so it's easy to tap by accident.
    // Unfinished sets get a sterner warning; a complete workout gets a plain
    // "save this?" confirm.
    final hasIncomplete = session.exercises.any(
      (ex) => ex.sets.any((s) => !s.isCompleted),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          hasIncomplete ? l10n.unfinishedSets : l10n.finish,
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Text(
          hasIncomplete
              ? l10n.unfinishedSetsMessage
              : l10n.finishWorkoutConfirm,
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
            child: Text(l10n.finish, style: TextStyle(color: colors.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Snapshot BEFORE finishing: finishSession() resets the live state, so the
    // share card is built from this pre-finish immutable instance, not from a
    // post-finish (wiped) read.
    final snapshot = session;

    // Finish first, OUTSIDE the share try — a (very unlikely) local-DB finish
    // failure must propagate/log as before, never be masked by share fallback.
    await notifier.finishSession();
    if (!mounted) return;

    // Build the share card defensively: it must never block a saved workout.
    ShareCardData? data;
    try {
      var n = 0;
      try {
        // Nth workout — invalidate first so the count includes the one just
        // saved. Optional: the card hides the number when it's 0.
        ref.invalidate(lifetimeStatsProvider);
        n = (await ref.read(lifetimeStatsProvider.future)).sessionCount;
      } on Object {
        // Count is a nice-to-have; a stats failure shouldn't lose the card.
      }

      if (!mounted) return;
      final workoutName = deriveWorkoutName(
        snapshot.exercises.map((e) => e.muscleGroup),
      );
      data = ShareCardData.fromActiveSession(
        snapshot,
        workoutName: workoutName,
        workoutNumber: n,
      );
    } on Object {
      data = null;
    }
    if (!mounted) return;

    // Replace the active-session route with the share sheet via go_router — NOT
    // Navigator.pushReplacement, which imperatively removes a page-based route
    // go_router can't observe (it would leave a phantom /session in the match
    // list that a later redirect refresh re-materialises over home).
    // context.pushReplacement keeps the router stack synced; the share screen's
    // X / Done then pop straight back to home.
    if (data != null) {
      context.pushReplacement(AppRoutes.shareCard, extra: data);
    } else {
      context.pop();
    }
  }

  Future<void> _discard() async {
    final notifier = ref.read(activeSessionProvider.notifier);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(l10n.discard, style: TextStyle(color: colors.textPrimary)),
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
            child: Text(l10n.discard, style: TextStyle(color: colors.danger)),
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

  /// Wheel picker for the default rest duration (clock icon). The running
  /// countdown pill still opens [_RestSheet].
  void _showRestPickerSheet() {
    final exercise = ref.read(activeSessionProvider).currentExercise;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RestPickerSheet(exerciseName: exercise?.name),
    );
  }

  Future<void> _addExerciseFlow() async {
    final notifier = ref.read(activeSessionProvider.notifier);
    final exerciseId = await context.push<String>(AppRoutes.exerciseBrowser);
    if (exerciseId != null) {
      await notifier.addExercise(exerciseId);
    }
  }

  /// The swipe-up actions drawer: Add Exercise / Edit Exercises / Settings
  /// pills with the Finish + Discard row at the bottom.
  void _showActionsSheet() {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    Widget actionPill(String label, VoidCallback onTap) {
      // button trait only — the visible text supplies the label.
      return Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 56.h,
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: colors.cardElevated,
              borderRadius: BorderRadius.circular(28.r),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),
              actionPill(l10n.addExercise, () {
                Navigator.pop(ctx);
                unawaited(_addExerciseFlow());
              }),
              actionPill(l10n.editExercises, () {
                Navigator.pop(ctx);
                _showEditExercisesSheet();
              }),
              actionPill(l10n.settings, () {
                Navigator.pop(ctx);
                unawaited(context.push(AppRoutes.settings));
              }),
              SizedBox(height: 4.h),
              _finishDiscardRow(colors, l10n, sheetCtx: ctx),
            ],
          ),
        ),
      ),
    );
  }

  /// Edit Exercises sheet: drag to reorder the session's exercises, tap the
  /// trash icon to remove one, tap a row to jump to it.
  void _showEditExercisesSheet() {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Consumer(
          builder: (ctx, ref, _) {
            final session = ref.watch(activeSessionProvider);
            final notifier = ref.read(activeSessionProvider.notifier);
            final exercises = session.exercises;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8.h),
                  Container(
                    width: 48.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    l10n.editExercises,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Flexible(
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                      itemCount: exercises.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex -= 1;
                        unawaited(
                          notifier.reorderExercises(oldIndex, newIndex),
                        );
                      },
                      proxyDecorator: (child, _, __) =>
                          Material(color: Colors.transparent, child: child),
                      itemBuilder: (ctx, i) {
                        final ex = exercises[i];
                        return Container(
                          key: ValueKey(ex.sessionExerciseId),
                          margin: EdgeInsets.only(bottom: 8.h),
                          decoration: BoxDecoration(
                            color: colors.cardElevated,
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: ListTile(
                            onTap: () {
                              notifier.selectExercise(i);
                              Navigator.pop(ctx);
                            },
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                            ),
                            leading: ReorderableDragStartListener(
                              index: i,
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: colors.textSecondary,
                                size: 22.sp,
                              ),
                            ),
                            title: Text(
                              ex.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${ex.sets.length} ${l10n.sets}',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12.sp,
                              ),
                            ),
                            trailing: Semantics(
                              button: true,
                              label: l10n.removeExercise,
                              child: GestureDetector(
                                onTap: () =>
                                    unawaited(notifier.removeExercise(i)),
                                behavior: HitTestBehavior.opaque,
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: colors.danger,
                                  size: 22.sp,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Anchored context menu on the title-row 3-dots (matches the Figma mock):
  /// Reorder / Replace / Add To Superset / Add To Warm Up / Remove.
  Future<void> _showExerciseMenu(BuildContext anchorCtx) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(activeSessionProvider.notifier);
    final box = anchorCtx.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + box.size.height + 2,
      overlay.size.width - origin.dx - 230.w,
      0,
    );

    PopupMenuItem<_ExerciseMenuAction> item({
      required _ExerciseMenuAction action,
      required Widget indicator,
      required String label,
      required Color color,
    }) => PopupMenuItem<_ExerciseMenuAction>(
      value: action,
      height: 40.h,
      child: Row(
        children: [
          SizedBox(
            width: 22.w,
            child: Center(child: indicator),
          ),
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

    final white = Colors.white.withValues(alpha: 0.92);
    const danger = Color(0xFFFF453A);

    final action = await showMenu<_ExerciseMenuAction>(
      context: context,
      position: position,
      color: const Color(0xF2202022),
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      constraints: BoxConstraints(minWidth: 195.w),
      items: [
        item(
          action: _ExerciseMenuAction.add,
          indicator: Icon(Icons.add_rounded, color: white, size: 16.sp),
          label: l10n.addExercise,
          color: white,
        ),
        item(
          action: _ExerciseMenuAction.reorder,
          indicator: Icon(Icons.swap_vert_rounded, color: white, size: 16.sp),
          label: l10n.reorderExercises,
          color: white,
        ),
        item(
          action: _ExerciseMenuAction.replace,
          indicator: Icon(Icons.sync_alt_rounded, color: white, size: 15.sp),
          label: l10n.replaceExercise,
          color: white,
        ),
        item(
          action: _ExerciseMenuAction.howTo,
          indicator: Icon(
            Icons.help_outline_rounded,
            color: white,
            size: 15.sp,
          ),
          label: l10n.howTo,
          color: white,
        ),
        item(
          action: _ExerciseMenuAction.remove,
          indicator: Icon(
            Icons.delete_outline_rounded,
            color: danger,
            size: 15.sp,
          ),
          label: l10n.removeExercise,
          color: danger,
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _ExerciseMenuAction.add:
        await _addExerciseFlow();
      case _ExerciseMenuAction.reorder:
        _showEditExercisesSheet();
      case _ExerciseMenuAction.replace:
        await _replaceExerciseFlow();
      case _ExerciseMenuAction.howTo:
        await _openExerciseDetail(
          ref.read(activeSessionProvider).currentExercise,
        );
      case _ExerciseMenuAction.remove:
        await notifier.removeCurrentExercise();
    }
  }

  /// Replace the current exercise: pick a new one from the browser, then
  /// remove the old one, keeping the new exercise at the old position.
  Future<void> _replaceExerciseFlow() async {
    final notifier = ref.read(activeSessionProvider.notifier);
    final session = ref.read(activeSessionProvider);
    final oldIndex = session.currentExerciseIndex;
    final hadExercise = session.currentExercise != null;
    final exerciseId = await context.push<String>(AppRoutes.exerciseBrowser);
    if (exerciseId == null) return;
    await notifier.addExercise(exerciseId); // appended + selected
    if (!hadExercise) return;
    await notifier.removeExercise(oldIndex);
    final lastIndex = ref.read(activeSessionProvider).exercises.length - 1;
    await notifier.reorderExercises(lastIndex, oldIndex);
  }

  /// Swipe anywhere on the screen body to switch exercise — same velocity
  /// rule as swiping the GIF card.
  void _handleExerciseSwipe(DragEndDetails details) {
    final session = ref.read(activeSessionProvider);
    final notifier = ref.read(activeSessionProvider.notifier);
    final v = details.primaryVelocity ?? 0;
    if (v < -200 &&
        session.currentExerciseIndex < session.exercises.length - 1) {
      notifier.selectExercise(session.currentExerciseIndex + 1);
    } else if (v > 200 && session.currentExerciseIndex > 0) {
      notifier.selectExercise(session.currentExerciseIndex - 1);
    }
  }

  /// Open the full exercise detail screen (summary, history, how-to) for
  /// the current exercise — tapping the GIF lands here.
  Future<void> _openExerciseDetail(ActiveExercise? exercise) async {
    if (exercise == null) return;
    final fullExercise = await ExerciseDao(
      ref.read(databaseProvider),
    ).findByExerciseId(exercise.exerciseId);
    if (fullExercise == null || !mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseDetailScreen(exercise: fullExercise),
      ),
    );
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
    required this.onBodyTap,
    this.bodyHidden = false,
  });
  final ActiveSessionState session;
  final ActiveSessionNotifier notifier;
  final ValueNotifier<int> elapsed;
  final AppLocalizations l10n;
  final AnatomyGender gender;
  final String skinPath;
  final VoidCallback onBodyTap;

  /// Hide the mini body while the anatomy island is expanded — the tap
  /// target stays so tapping the same spot closes it.
  final bool bodyHidden;

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
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Time — tap to pause/resume the session clock.
                // button trait so screen readers know it's actionable; the
                // "Time" label + value announce from the child texts.
                Semantics(
                  button: true,
                  child: GestureDetector(
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
                        builder: (_, seconds, __) =>
                            Text(_fmt(seconds), style: _valueStyle),
                      ),
                    ),
                  ),
                ),
                _StatColumn(
                  label: l10n.sets,
                  value: Text(
                    '${session.totalCompletedSets}',
                    style: _valueStyle,
                  ),
                ),
              ],
            ),
          ),
          // Center gap — the phone's camera notch / punch hole sits here,
          // between Sets and Volume.
          SizedBox(width: 120.w),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatColumn(
                  label: l10n.volume,
                  value: Text(
                    '${vol.round()} ${isLbs ? 'lbs' : 'kg'}',
                    style: _valueStyle,
                  ),
                ),
                // Tap the mini body to expand the anatomy island; it hides
                // while the island is open (the island shows the bodies).
                GestureDetector(
                  onTap: onBodyTap,
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: bodyHidden ? 0 : 1,
                    child: AnatomyBody(
                      muscleStates: muscleStates,
                      height: 42.h,
                      gender: gender,
                      basePngPath: skinPath,
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
    this.onTap,
    this.onSwipeLeft,
    this.onSwipeRight,
  });
  final ActiveExercise? exercise;

  /// Called when the GIF is tapped — opens the exercise detail (how-to + info).
  final VoidCallback? onTap;

  /// Called when the user swipes left (→ next exercise). Null when already at last.
  final VoidCallback? onSwipeLeft;

  /// Called when the user swipes right (→ previous exercise). Null when already at first.
  final VoidCallback? onSwipeRight;

  static const double _kVelocityThreshold = 200;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onTap: onTap,
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
                      memCacheWidth:
                          (260.w * MediaQuery.devicePixelRatioOf(context))
                              .toInt(),
                      memCacheHeight:
                          (250.h * MediaQuery.devicePixelRatioOf(context))
                              .toInt(),
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
// ANATOMY PANEL — replaces the GIF card when the mini body is
// tapped: bodies + per-muscle recovery bars, fading out at the
// bottom of the card (over the white base, per the mock).
// ═══════════════════════════════════════════════════════════════

class _AnatomyPanel extends ConsumerWidget {
  const _AnatomyPanel({required this.session, required this.onTap});
  final ActiveSessionState session;
  final VoidCallback onTap;

  /// Mock proportions: bodies sit just below the stats capsule, sized so
  /// ~5 muscle bars fit underneath with the reflection behind them.
  double get _kBodyTop => 62.h;
  double get _kBodyHeight => 150.h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Completed sets per muscle group — only what THIS session targeted.
    final setCounts = <String, int>{};
    for (final ex in session.exercises) {
      final group = ex.muscleGroup;
      if (group == null || ex.isCardio) continue;
      final done = ex.sets.where((s) => s.isCompleted).length;
      if (done > 0) setCounts[group] = (setCounts[group] ?? 0) + done;
    }
    // Most-targeted first; bars are relative to the top muscle (= 100%).
    final muscles = setCounts.keys.toList()
      ..sort((a, b) => setCounts[b]!.compareTo(setCounts[a]!));
    final maxSets = muscles.isEmpty ? 1 : setCounts[muscles.first]!;

    // Highlight the session's muscles on the bodies, like the mini body.
    final states = [
      for (final g in muscles)
        MuscleStateInfo(
          muscleGroup: g,
          state: MuscleState.recovering,
          recoveryPercent: 0,
        ),
    ];

    final gender = ref.watch(anatomyGenderProvider);
    final skinPath = ref.watch(activeSkinPathProvider);

    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        // Stays within the exercise-GIF card (330.h, panel top at 4.h).
        height: 322.h,
        radius: 44.r,
        // Very light base frost + strong blur so the bottom reads as real
        // glass (the top darkness comes from the gradient overlay, not this).
        tint: Colors.white.withValues(alpha: 0.06),
        blurSigma: AppGlass.blurStrong,
        borderColor: Colors.white.withValues(alpha: 0.12),
        shadow: BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 30.w,
          offset: Offset(0, 12.h),
        ),
        child: Stack(
          children: [
            // Solid capsule-black from the top, staying dark until near the
            // bottom, then dissolving into bare glass — the mock's fade.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      Colors.black,
                      // Fully transparent at the bottom → only the light
                      // frost + strong blur remain, so it reads as real glass
                      // (like the nav pill), not a dark patch.
                      Colors.black.withValues(alpha: 0),
                    ],
                    // Solid black through the bodies + first bar (~0.66),
                    // then a long gradual fade into the glass at the bottom.
                    stops: const [0, 0.66, 1],
                  ),
                ),
              ),
            ),
            // Mirror-floor reflection under the bodies' feet — flipped,
            // blurred and fading out, showing through behind the bars
            // (per the mock).
            Positioned(
              top: _kBodyTop + _kBodyHeight,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ShaderMask(
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.75],
                  ).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Transform.scale(
                      scaleY: -1,
                      child: AnatomyBody(
                        muscleStates: states,
                        height: _kBodyHeight,
                        gender: gender,
                        basePngPath: skinPath,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                // The floating stats capsule sits inside the card's top edge.
                SizedBox(height: _kBodyTop),
                AnatomyBody(
                  muscleStates: states,
                  height: _kBodyHeight,
                  gender: gender,
                  basePngPath: skinPath,
                ),
                SizedBox(height: 16.h),
                // Bars stay bright the whole way down (only the background
                // fades). A tiny edge fade lets overflow rows hint-fade.
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0, 0.94, 1],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(28.w, 0, 28.w, 30.h),
                      itemCount: muscles.length,
                      itemBuilder: (_, i) => _muscleBarRow(
                        muscles[i],
                        setCounts[muscles[i]]! / maxSets,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _muscleBarRow(String muscleGroup, double fraction) {
    final percentLabel = '${(fraction * 100).round()}%';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          SizedBox(
            width: 72.w,
            child: Text(
              muscleGroup,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Pill bar per the mock: the unfilled remainder is a dim,
          // olive version of the accent (not grey), and the fill is a
          // fully-rounded capsule of its own.
          Expanded(
            child: SizedBox(
              height: 5.h,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(2.5.r),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    // Container (not a bare ColoredBox) so the fill
                    // expands to the track height instead of collapsing.
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2.5.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 44.w,
            child: Text(
              percentLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
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
                  color: i <= current
                      ? colors.accent
                      : colors.accent.withValues(alpha: 0.2),
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
// SETS TABLE — non-scrolling column of glassy set-row pills
// ═══════════════════════════════════════════════════════════════

class _SetsTable extends StatelessWidget {
  const _SetsTable({
    required this.exercise,
    required this.notifier,
    required this.l10n,
  });
  final ActiveExercise exercise;
  final ActiveSessionNotifier notifier;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // ponytail: plain Column, no scroll — realistic workouts stay well under
    // ~7 sets per exercise. Rows past the screen bottom clip behind the
    // floating chrome; bring back a scrollable if that ever bites.
    return Column(
      children: [
        for (final s in exercise.sets)
          _SetRow(
            key: ValueKey('set_row_${s.localId}'),
            set: s,
            exercise: exercise,
            notifier: notifier,
            unit: notifier.weightUnit,
          ),
        Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: _buildAddSetButton(context),
        ),
      ],
    );
  }

  Widget _buildAddSetButton(BuildContext context) {
    // Frosted, not refractive: the oc_liquid_glass shader is an unclipped
    // BackdropFilter that force-writes opaque pixels, so inside this scrolling
    // viewport it repaints the whole viewport backdrop — which renders black
    // on Android (Impeller) in light mode while scrolling.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnHeight = 36.h;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      // button: true only — the visible "Add set" Text supplies the label.
      child: Semantics(
        button: true,
        child: GlassSurface(
          height: btnHeight,
          radius: btnHeight / 2,
          blurSigma: AppGlass.blurButton,
          shadow: GlassDecoration.shadow(isDark: isDark),
          onTap: notifier.addSet,
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SET ROW — glassy pill + check button; completed rows take the
// set-type color. Drag the check button left to arm delete.
// ═══════════════════════════════════════════════════════════════

enum _SetMenuAction { normal, warmUp, superset, dropset, failure, remove }

enum _ExerciseMenuAction { add, reorder, replace, howTo, remove }

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
        // Absorb horizontal drags here too — no exercise swipe while the
        // delete confirm is showing.
        child: GestureDetector(
          onHorizontalDragEnd: (_) {},
          child: _deleteBar(l10n, barHeight),
        ),
      );
    }

    final type = widget.set.setType;
    final typeColor = setTypeColor(type);
    final completed = widget.set.isCompleted;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 5.h),
      // Absorb horizontal drags on the whole row so the screen-level
      // exercise swipe never fires here — the check button's own drag
      // (deeper in the tree) still wins over this one.
      child: GestureDetector(
        onHorizontalDragEnd: (_) {},
        child: SizedBox(
          height: barHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: _bar(
                  colors,
                  l10n,
                  type,
                  typeColor,
                  completed,
                  barHeight,
                ),
              ),
              // Red delete reveal — only the swept part of the bar (right of
              // the dragged button) turns red; the rest keeps its color.
              if (_dragX < 0)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: -_dragX + 58.w,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A1215),
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: _checkButton(colors, typeColor, completed, barHeight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── The pill bar ──

  Widget _bar(
    AppColorsTheme colors,
    AppLocalizations l10n,
    SetType type,
    Color typeColor,
    bool completed,
    double barHeight,
  ) {
    // The bar spans the full row width now (the check button sits on top of
    // its right end), so keep the content clear of the button area.
    final content = Padding(
      padding: EdgeInsets.only(right: 58.w),
      child: widget.exercise.isCardio
          ? _cardioContent(colors, l10n, type, typeColor, completed)
          : _strengthContent(colors, l10n, type, typeColor, completed),
    );

    if (completed) {
      return Container(
        height: barHeight,
        decoration: BoxDecoration(
          // Dark tint of the type color — text/values take the full color.
          color: Color.alphaBlend(
            typeColor.withValues(alpha: 0.22),
            Colors.black,
          ),
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

  // Text colors: type-color-on-dark-tint when completed, theme colors otherwise.
  Color _primaryText(AppColorsTheme colors, bool completed, Color typeColor) =>
      completed ? typeColor : colors.textPrimary;
  Color _secondaryText(
    AppColorsTheme colors,
    bool completed,
    Color typeColor,
  ) => completed ? typeColor.withValues(alpha: 0.7) : colors.textSecondary;

  Widget _strengthContent(
    AppColorsTheme colors,
    AppLocalizations l10n,
    SetType type,
    Color typeColor,
    bool completed,
  ) {
    final primary = _primaryText(colors, completed, typeColor);
    final secondary = _secondaryText(colors, completed, typeColor);

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
                  onChanged: (v) => widget.notifier.updateSet(
                    widget.set.localId,
                    weightStr: v,
                  ),
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

  Widget _cardioContent(
    AppColorsTheme colors,
    AppLocalizations l10n,
    SetType type,
    Color typeColor,
    bool completed,
  ) {
    final primary = _primaryText(colors, completed, typeColor);
    final secondary = _secondaryText(colors, completed, typeColor);

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
                    (v) => widget.notifier.updateSet(
                      widget.set.localId,
                      durationStr: v,
                    ),
                  ),
                  field(
                    widget.notifier.displayDouble(widget.set.distance),
                    'km',
                    (v) => widget.notifier.updateSet(
                      widget.set.localId,
                      distanceStr: v,
                    ),
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
  Widget _setLabel(
    AppColorsTheme colors,
    AppLocalizations l10n,
    SetType type,
    Color typeColor,
    bool completed,
  ) {
    final indicator = switch (type) {
      SetType.normal => '${widget.set.setIndex + 1}',
      SetType.warmUp => 'W',
      SetType.superset => 'S',
      SetType.dropset => 'D',
      SetType.failure => 'F',
    };
    final indicatorColor = completed
        ? typeColor
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
                  color: _secondaryText(colors, completed, typeColor),
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
    }) => PopupMenuItem<_SetMenuAction>(
      value: action,
      height: 40.h,
      child: Row(
        children: [
          SizedBox(
            width: 22.w,
            child: Center(child: indicator),
          ),
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
      style: TextStyle(color: c, fontSize: 13.sp, fontWeight: FontWeight.w800),
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
          indicator: Icon(
            Icons.delete_outline_rounded,
            color: danger,
            size: 15.sp,
          ),
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
        await widget.notifier.updateSetType(
          widget.set.localId,
          SetType.superset,
        );
      case _SetMenuAction.dropset:
        await widget.notifier.updateSetType(
          widget.set.localId,
          SetType.dropset,
        );
      case _SetMenuAction.failure:
        await widget.notifier.updateSetType(
          widget.set.localId,
          SetType.failure,
        );
      case _SetMenuAction.remove:
        _arm(); // same press-to-confirm bar as the drag gesture
    }
  }

  // ── Check button (tap = complete/uncomplete, drag left = arm delete) ──

  Widget _checkButton(
    AppColorsTheme colors,
    Color typeColor,
    bool completed,
    double barHeight,
  ) {
    final button = completed
        ? Container(
            width: 58.w,
            height: barHeight,
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(barHeight / 2),
            ),
            child: Center(
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 24.sp,
              ),
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

    // Icon-only toggle: name it for screen readers. The label flips with the
    // state so VoiceOver reads what the tap will do next.
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: completed ? l10n.markSetIncomplete : l10n.markSetComplete,
      child: GestureDetector(
        onTap: () {
          if (completed) {
            HapticFeedback.selectionClick();
            widget.notifier.uncompleteSet(widget.set.localId);
          } else {
            widget.notifier.completeSet(widget.set.localId);
          }
        },
        // Draggable across the whole bar (row width minus side padding and
        // the button itself), not just a short throw.
        onHorizontalDragUpdate: (d) => setState(
          () => _dragX = (_dragX + d.delta.dx).clamp(
            -(MediaQuery.sizeOf(context).width - 40.w - 58.w),
            0.0,
          ),
        ),
        onHorizontalDragEnd: (_) {
          if (_dragX < _kArmThreshold) {
            _arm();
          } else {
            setState(() => _dragX = 0);
          }
        },
        onHorizontalDragCancel: () => setState(() => _dragX = 0),
        child: Transform.translate(offset: Offset(_dragX, 0), child: button),
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
          // X — cancel (icon-only, so it carries a semantic label).
          Semantics(
            button: true,
            label: l10n.cancel,
            child: GestureDetector(
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
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Press the text to confirm the delete.
          Expanded(
            child: Semantics(
              button: true,
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
          ),
          // Balance the X circle so the text is optically centered.
          SizedBox(width: barHeight - 4.w),
        ],
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
    final running = ref.watch(
      activeSessionProvider.select((s) => s.showRestTimer),
    );

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
                  // One meaningful announcement ("Rest timer, 1:30 remaining")
                  // instead of the two raw texts. Not a live region — that
                  // would re-announce every second.
                  return Semantics(
                    label: running
                        ? l10n.restTimerRemaining(timeStr)
                        : l10n.restTimer,
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 150.w,
                      height: 150.w,
                      child: CustomPaint(
                        painter: _TimerRingPainter(
                          progress: running
                              ? notifier.restTimerService.progress
                              : 0,
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
                    ),
                  );
                },
              ),
              SizedBox(height: 18.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chip(
                    context,
                    '-15s',
                    running
                        ? () => notifier.restTimerService.addTime(-15)
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  _chip(
                    context,
                    '+15s',
                    running
                        ? () => notifier.restTimerService.addTime(15)
                        : null,
                  ),
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

  Widget _chip(
    BuildContext context,
    String label,
    VoidCallback? onTap, {
    bool accent = false,
  }) {
    final colors = AppColors.of(context);
    final enabled = onTap != null;
    // button + enabled traits; the visible text supplies the label.
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
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
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  _TimerRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.accentColor,
  });
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
  bool shouldRepaint(_TimerRingPainter old) =>
      old.progress != progress || old.accentColor != accentColor;
}

// ═══════════════════════════════════════════════════════════════
// REST PICKER SHEET — default rest duration wheel (Figma mock)
// ═══════════════════════════════════════════════════════════════

class _RestPickerSheet extends ConsumerStatefulWidget {
  const _RestPickerSheet({required this.exerciseName});
  final String? exerciseName;

  @override
  ConsumerState<_RestPickerSheet> createState() => _RestPickerSheetState();
}

class _RestPickerSheetState extends ConsumerState<_RestPickerSheet> {
  static const _step = 5;
  static const _maxSeconds = 300;

  late int _seconds;
  late final FixedExtentScrollController _wheel;

  @override
  void initState() {
    super.initState();
    final current =
        ref.read(userProfileProvider).valueOrNull?.defaultRestSeconds ?? 90;
    _seconds = current.clamp(0, _maxSeconds);
    _wheel = FixedExtentScrollController(initialItem: _seconds ~/ _step);
  }

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  String _label(int s, AppLocalizations l10n) {
    if (s <= 0) return l10n.off;
    if (s < 60) return '${s}s';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Persist to the profile — the session notifier picks it up through the
  /// userProfileProvider listener in activeSessionProvider.
  Future<void> _save() async {
    final dao = ref.read(userProfileDaoProvider);
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile == null) {
      await dao.upsert(
        UserProfilesCompanion(defaultRestSeconds: Value(_seconds)),
      );
    } else {
      await dao.updateRestSeconds(profile.localId, _seconds);
    }
    ref.invalidate(userProfileProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 12.h),
      child: SafeArea(
        top: false,
        child: GlassSurface(
          radius: 32.r,
          tint: colors.panelBackground.withValues(alpha: 0.78),
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: centered title + exercise name.
              Text(
                l10n.restTimer,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.exerciseName != null) ...[
                SizedBox(height: 2.h),
                Text(
                  widget.exerciseName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: 10.h),
              SizedBox(
                height: 170.h,
                child: CupertinoPicker(
                  scrollController: _wheel,
                  itemExtent: 40.h,
                  squeeze: 1.1,
                  selectionOverlay: Container(
                    margin: EdgeInsets.symmetric(horizontal: 24.w),
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  onSelectedItemChanged: (i) {
                    HapticFeedback.selectionClick();
                    _seconds = i * _step;
                  },
                  children: [
                    for (var s = 0; s <= _maxSeconds; s += _step)
                      Center(
                        child: Text(
                          _label(s, l10n),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              GestureDetector(
                onTap: () => unawaited(_save()),
                child: Container(
                  width: double.infinity,
                  height: 52.h,
                  decoration: BoxDecoration(
                    // Dark accent tint + accent text (mock); solid accent in
                    // light mode where the tint would wash out.
                    color: isDark
                        ? Color.alphaBlend(
                            colors.accent.withValues(alpha: 0.45),
                            colors.card,
                          )
                        : colors.accent,
                    borderRadius: BorderRadius.circular(26.r),
                  ),
                  child: Center(
                    child: Text(
                      l10n.done,
                      style: TextStyle(
                        color: isDark ? colors.accent : colors.todayPillText,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
