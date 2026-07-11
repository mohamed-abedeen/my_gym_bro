import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/active_session/active_session_notifier.dart';
import 'package:my_gym_bro/features/workout/log_bottom_sheet.dart';
import 'package:my_gym_bro/features/workout/muscle_detail_sheet.dart';
import 'package:my_gym_bro/features/workout/status_bottom_sheet.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/app_fonts.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Workout tab — pixel-perfect from Figma CSS.
class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final colors = AppColors.of(context);

    return Stack(
      children: [
        // ── Grey background covering upper half ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.5,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:
                    isDark
                        ? [Color(0xFF1A1A1A), AppColors.of(context).black]
                        : [colors.panelBackground, colors.background],
              ),
            ),
          ),
        ),

        // ── Scrollable content ──
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(l10n: l10n),
            SizedBox(height: 16.h),

            // Anatomy — gender-aware front + back body views
            _AnatomySection(l10n: l10n),

            SizedBox(height: 1.h),

            // Sessions Log + Status cards row
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.contentPaddingH.w,
              ),
              child: _StatsRow(l10n: l10n),
            ),

            SizedBox(height: 12.h),

            // Schedule card (swipeable) + page dots
            _ScheduleCard(l10n: l10n),

            SizedBox(height: 16.h),
          ],
        ),

        // ── Resume-workout pill — hovers while a session is live ──
        const _ResumeSessionPill(),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Resume-workout pill — shown while an active session exists after the
// user backed out of the active screen. Tap = reopen, bin = discard.
// ═══════════════════════════════════════════════════════════════════
class _ResumeSessionPill extends ConsumerStatefulWidget {
  const _ResumeSessionPill();

  @override
  ConsumerState<_ResumeSessionPill> createState() =>
      _ResumeSessionPillState();
}

class _ResumeSessionPillState extends ConsumerState<_ResumeSessionPill> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Tick the elapsed label once a second while a session is live.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(activeSessionProvider).sessionId != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _fmt(int s) {
    if (s < 60) return '${s}s';
    if (s < 3600) return '${s ~/ 60}m';
    return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';
  }

  Future<void> _discard() async {
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
    await ref.read(activeSessionProvider.notifier).discardSession();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session.sessionId == null) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    Widget circleButton({
      required Widget child,
      required VoidCallback onTap,
      Color? color,
    }) =>
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: color ?? Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Center(child: child),
          ),
        );

    return Positioned(
      left: 20.w,
      right: 20.w,
      bottom: MediaQuery.of(context).padding.bottom + 92.h,
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.activeSession),
        child: GlassSurface(
          radius: 34.r,
          tint: colors.panelBackground.withValues(alpha: 0.85),
          padding: EdgeInsets.all(10.w),
          shadow: BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18.w,
            offset: Offset(0, 6.h),
          ),
          child: Row(
            children: [
              circleButton(
                onTap: () => context.push(AppRoutes.activeSession),
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: colors.textPrimary,
                  size: 26.sp,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: colors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          l10n.tabWorkout,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 5.w),
                        Text(
                          _fmt(session.elapsedSeconds),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      session.currentExercise?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              circleButton(
                onTap: _discard,
                color: const Color(0xFF3E1418),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: const Color(0xFFFF453A),
                  size: 22.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header: "Workout" + fire streak + glass menu button
// ═══════════════════════════════════════════════════════════════════
class _Header extends ConsumerWidget {
  const _Header({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final streak = ref.watch(streakProvider).asData?.value ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10.h,
        left: AppSizes.contentPaddingH.w,
        right: AppSizes.contentPaddingH.w,
      ),
      child: Row(
        children: [
          // Title
          Text(
            l10n.tabWorkout,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 36.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 8.w),

          // Fire streak icon + count
          Icon(Icons.local_fire_department, color: colors.amber, size: 26.sp),
          SizedBox(width: 2.w),
          Text(
            '$streak',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
            ),
          ),

          const Spacer(),

          // Glass menu button (48x48, 0.25 opacity)
          LiquidGlassButton(
            width: 48.w,
            height: 48.w,
            opacity: 0.25,
            radius: 24.r,
            onTap: () => context.push(AppRoutes.settings),
            child: Icon(
              Icons.menu_rounded,
              color: colors.textPrimary,
              size: 24.sp,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Anatomy section — gender-aware front + back body views
// Shows muscle recovery state via color (red = recovering, green = recovered)
// Gradient background #1A1A1A → black per Figma
// ═══════════════════════════════════════════════════════════════════
class _AnatomySection extends ConsumerWidget {
  const _AnatomySection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final muscleStates = ref.watch(muscleRecoveryProvider);

    return GestureDetector(
      onTap: () => showMuscleDetailSheet(context),
      child: SizedBox(
        width: double.infinity,
        height: 350.h,
        child: Center(
          child: muscleStates.when(
            data:
                (states) => AnatomyBody(
                  muscleStates: states,
                  height: 350.h,
                  gender: ref.watch(anatomyGenderProvider),
                  basePngPath: ref.watch(activeSkinPathProvider),
                ),
            loading:
                () => SizedBox(
                  height: 350.h,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: colors.accent,
                      strokeWidth: 2.w,
                    ),
                  ),
                ),
            error:
                (_, __) => AnatomyBody(
                  muscleStates: const [],
                  height: 350.h,
                  gender: ref.watch(anatomyGenderProvider),
                  basePngPath: ref.watch(activeSkinPathProvider),
                ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Stats row: Sessions Log (left) + Status (right)
// ═══════════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _SessionsLogCard(l10n: l10n)),
          SizedBox(width: 12.w),
          Expanded(child: _StatusLogCard(l10n: l10n)),
        ],
      ),
    );
  }
}

// ── Sessions Log Card ──
// Figma: 194x159, bg #1C1C1E, radius 24
class _SessionsLogCard extends ConsumerWidget {
  const _SessionsLogCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final enriched = ref.watch(enrichedRecentSessionsProvider);

    return GestureDetector(
      onTap: () => showLogBottomSheet(context),
      child: Container(
        height: 159.h,
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    l10n.sessionLog,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colors.textPrimary,
                  size: 15.sp,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: enriched.when(
                data:
                    (list) =>
                        list.isEmpty
                            ? Center(
                              child: Text(
                                l10n.noRecordsYet,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children:
                                  list
                                      .map((e) => _SessionRow(enriched: e))
                                      .toList(),
                            ),
                loading:
                    () => Center(
                      child: CircularProgressIndicator(
                        color: colors.accent,
                        strokeWidth: 2.w,
                      ),
                    ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.enriched});
  final EnrichedSession enriched;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dayAbbr = DateFormat.E()
        .format(enriched.session.startedAt)
        .substring(0, 3);
    final label = '$dayAbbr, ${enriched.workoutName}';

    return Row(
      children: [
        Container(
          width: 27.w,
          height: 27.w,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sessionIcon.r),
          ),
          child: Icon(
            Icons.fitness_center_rounded,
            color: colors.accent,
            size: 16.sp,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Status Log Card ──
// Figma: 194x159, bg #1C1C1E, radius 24
// Labels 11px w400, values 13px w700, arrows 24x24 rotated -90deg
class _StatusLogCard extends ConsumerWidget {
  const _StatusLogCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final stats = ref.watch(weeklyStatsProvider);
    final unit = ref.watch(weightUnitProvider);

    return GestureDetector(
      onTap: () => showStatusBottomSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    l10n.statusLog,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colors.textPrimary,
                  size: 15.sp,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            stats.when(
              data:
                  (s) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatLine(
                        label: l10n.volume,
                        value: formatWeight(
                          s.totalVolume,
                          unit,
                          decimals: 0,
                          withUnit: true,
                        ),
                        trend: s.volumeTrend,
                      ),
                      SizedBox(height: 2.h),
                      _StatLine(
                        label: l10n.totalDuration,
                        value: s.formattedDuration,
                        trend: s.durationTrend,
                        trendSuffix: '%',
                      ),
                      SizedBox(height: 2.h),
                      _StatLine(
                        label: l10n.avgStrength,
                        value: formatWeight(
                          s.avgStrength,
                          unit,
                          decimals: 0,
                        ),
                        trend: s.strengthTrend,
                      ),
                    ],
                  ),
              loading:
                  () => Center(
                    child: CircularProgressIndicator(
                      color: colors.accent,
                      strokeWidth: 2.w,
                    ),
                  ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.label,
    required this.value,
    this.trend,
    this.trendSuffix = '',
  });
  final String label;
  final String value;
  final double? trend;
  final String trendSuffix;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isPositive = trend != null && trend! >= 0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (trend != null) ...[
          Text(
            '${trend! >= 0 ? '+' : ''}${trend!.toInt()}$trendSuffix',
            style:
                isPositive
                    ? AppFonts.trendPositive(context)
                    : AppFonts.trendNegative(context),
          ),
          SizedBox(width: 2.w),
          // Arrow rotated -90deg (pointing up-right / down-right)
          Transform.rotate(
            angle:
                isPositive ? AppAngles.quarterTurnCcw : AppAngles.quarterTurnCw,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: isPositive ? colors.trendPositive : colors.trendNegative,
              size: 24.sp,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Schedule card: swipeable between days of the selected program
// Figma: 400x180, bg #1C1C1E, radius 40
// Swipe cycles through days within one program.
// The program picker (bottom button) switches to a different program.
// ═══════════════════════════════════════════════════════════════════
class _ScheduleCard extends ConsumerStatefulWidget {
  const _ScheduleCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  ConsumerState<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends ConsumerState<_ScheduleCard> {
  PageController? _pageController;
  int _lastSyncedPage = -1;

  /// True while WE move the pager (auto-advance / program-change jumps) —
  /// jumpToPage fires onPageChanged too, and those must not count as the
  /// user picking a page.
  bool _syncingPage = false;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(allSchedulesProvider);
    final schedules = schedulesAsync.valueOrNull ?? [];
    final cardState = ref.watch(workoutCardStateProvider);

    // No programs at all → show only "Add Day" card
    if (schedules.isEmpty) {
      return Column(
        children: [
          SizedBox(
            height: AppSizes.scheduleCardH.h,
            child: _AddDayCard(l10n: widget.l10n),
          ),
        ],
      );
    }

    // Resolve which schedule is selected (default: the active one)
    final selected = schedules.firstWhere(
      (s) => s.localId == cardState.selectedScheduleId,
      orElse:
          () => schedules.firstWhere(
            (s) => s.isActive,
            orElse: () => schedules.first,
          ),
    );

    // Watch the days for the selected schedule
    final daysAsync = ref.watch(scheduleDaysProvider(selected.localId));
    final allDays = daysAsync.valueOrNull ?? [];
    // Filter out rest days for the card swiper — rest days don't need play/edit.
    final trainingDays = allDays.where((d) => !d.isRestDay).toList();

    // Total pages: training days + "Add Day" card at the end
    final totalPages = trainingDays.length + 1;

    // Auto-advance: determine which training day is next based on completed sessions
    final nextDayAsync = ref.watch(
      nextTrainingDayIndexProvider(selected.localId),
    );
    final autoPage = nextDayAsync.valueOrNull;

    // Use auto-advance page until the user manually swipes, then respect
    // their choice. (Keyed on an explicit flag, NOT `currentPage == 0` —
    // that made swiping back to the first card impossible, since landing
    // on page 0 re-triggered the auto jump.)
    final effectivePage =
        (!cardState.userPickedPage && autoPage != null)
            ? autoPage
            : cardState.currentPage;
    final safePage = effectivePage.clamp(0, totalPages - 1);

    // Create the PageController once, then sync page changes via jumpToPage
    // post-frame. Recreating/disposing it on every build() leaked controllers
    // and caused a flicker mid-frame.
    _pageController ??= PageController(initialPage: safePage);
    if (_lastSyncedPage != safePage) {
      _lastSyncedPage = safePage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _pageController;
        if (c != null && c.hasClients && c.page?.round() != safePage) {
          _syncingPage = true;
          c.jumpToPage(safePage);
          _syncingPage = false;
        }
      });
    }

    return Column(
      children: [
        SizedBox(
          height: AppSizes.scheduleCardH.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            onPageChanged: (i) {
              final notifier = ref.read(workoutCardStateProvider.notifier);
              notifier.state = notifier.state.copyWith(
                currentPage: i,
                // Only a real user swipe locks the page; programmatic
                // jumps keep auto-advance alive.
                userPickedPage: _syncingPage ? null : true,
              );
            },
            itemBuilder: (context, i) {
              // Last page = "Add Day"
              if (i >= trainingDays.length) {
                return _AddDayCard(
                  l10n: widget.l10n,
                  schedule: selected,
                  allSchedules: schedules,
                  onProgramChanged: _onProgramChanged,
                );
              }
              return _DayCard(
                l10n: widget.l10n,
                schedule: selected,
                day: trainingDays[i],
                allSchedules: schedules,
                onProgramChanged: _onProgramChanged,
              );
            },
          ),
        ),
        SizedBox(height: 12.h),
        _PageDots(activeIndex: safePage, count: totalPages),
      ],
    );
  }

  void _onProgramChanged(int scheduleId) {
    // Reset to page 0; the auto-advance logic in build() will jump
    // to the correct next training day once the provider resolves.
    ref.read(workoutCardStateProvider.notifier).state = WorkoutCardState(
      selectedScheduleId: scheduleId,
    );
    SecureStorage().write('last_selected_schedule_id', scheduleId.toString());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController?.hasClients ?? false) {
        _syncingPage = true;
        _pageController!.jumpToPage(0);
        _syncingPage = false;
      }
    });
  }
}

// ── "Add Day" card — shown as the last swipeable page, or alone if no programs ──
class _AddDayCard extends StatelessWidget {
  const _AddDayCard({
    required this.l10n,
    this.schedule,
    this.allSchedules = const [],
    this.onProgramChanged,
  });
  final AppLocalizations l10n;
  final Schedule? schedule;
  final List<Schedule> allSchedules;
  final ValueChanged<int>? onProgramChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
      height: AppSizes.scheduleCardH.h,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(AppRadius.schedule.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Title + subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.addDayTitle,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 36.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      l10n.oneStepCloserBro,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                // Bottom: program picker or "New Program"
                GestureDetector(
                  onTap:
                      allSchedules.length > 1 && schedule != null
                          ? () => _showProgramPicker(
                            context,
                            schedule!,
                            allSchedules,
                            onProgramChanged,
                          )
                          : () => context.push(AppRoutes.scheduleBuilder),
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          schedule?.name ?? l10n.newProgram,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (allSchedules.length > 1) ...[
                          SizedBox(width: 3.w),
                          Icon(
                            Icons.unfold_more_rounded,
                            color: colors.textPrimary,
                            size: 18.sp,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Green + button
              GestureDetector(
                onTap:
                    () => context.push(
                      AppRoutes.scheduleBuilder,
                      extra: schedule?.localId,
                    ),
                child: Container(
                  width: 69.w,
                  height: 68.h,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(
                      AppRadius.scheduleCircle.r,
                    ),
                  ),
                  child: Icon(Icons.add, color: colors.todayPillText, size: 46.sp),
                ),
              ),
              SizedBox(height: 8.h),
              // White search button
              GestureDetector(
                onTap: () => context.push(AppRoutes.exerciseBrowser),
                child: Container(
                  width: 69.w,
                  height: 64.h,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).white,
                    borderRadius: BorderRadius.circular(
                      AppRadius.scheduleCircle.r,
                    ),
                  ),
                  child: Icon(Icons.search, color: colors.todayPillText, size: 33.sp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Day card — one training day within a program ──
class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.l10n,
    required this.schedule,
    required this.day,
    required this.allSchedules,
    required this.onProgramChanged,
  });
  final AppLocalizations l10n;
  final Schedule schedule;
  final ScheduleDay day;
  final List<Schedule> allSchedules;
  final ValueChanged<int> onProgramChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final dayLabel = day.label ?? 'Day ${day.dayIndex + 1}';

    // Recovery-based readiness timer — checks actual muscle recovery state
    final recoveryAsync = ref.watch(dayRecoveryStatusProvider(day.localId));
    final timerText = recoveryAsync.when(
      data: (status) {
        if (status.isReady) return l10n.readyToTrain;
        if (status.bottleneckMuscle != null) {
          return l10n.readyInHoursMuscle(
            status.hoursRemaining!,
            status.bottleneckMuscle!,
          );
        }
        return l10n.nextSessionAfter(status.hoursRemaining!);
      },
      loading: () => l10n.readyToTrain,
      error: (_, __) => l10n.readyToTrain,
    );

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
      height: AppSizes.scheduleCardH.h,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(AppRadius.schedule.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Day name as big title + next session subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 36.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      timerText,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                // Program name selector at bottom
                GestureDetector(
                  onTap:
                      () => _showProgramPicker(
                        context,
                        schedule,
                        allSchedules,
                        onProgramChanged,
                      ),
                  child: Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          schedule.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Icon(
                          Icons.unfold_more_rounded,
                          color: colors.textPrimary,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play button
              GestureDetector(
                onTap: () =>
                    context.push(AppRoutes.activeSession, extra: day.localId),
                child: Container(
                  width: 69.w,
                  height: 68.h,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(
                      AppRadius.scheduleCircle.r,
                    ),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.of(context).black,
                    size: 36.sp,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              // Edit button
              GestureDetector(
                onTap:
                    () => context.push(
                      AppRoutes.scheduleBuilder,
                      extra: schedule.localId,
                    ),
                child: Container(
                  width: 69.w,
                  height: 64.h,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).white,
                    borderRadius: BorderRadius.circular(
                      AppRadius.scheduleCircle.r,
                    ),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: AppColors.of(context).black,
                    size: 33.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// ── Shared program picker — used by both _DayCard and _AddDayCard ──
Future<void> _showProgramPicker(
  BuildContext context,
  Schedule currentSchedule,
  List<Schedule> schedules,
  ValueChanged<int>? onProgramChanged,
) async {
  final box = context.findRenderObject()! as RenderBox;
  final offset = box.localToGlobal(Offset.zero);
  final colors = AppColors.of(context);

  // Same dark panel as the other context menus, in BOTH themes (Figma mock)
  // — a theme-following card blends into the page behind it.
  final white = Colors.white.withValues(alpha: 0.92);
  final divider = PopupMenuDivider(
    height: 1,
    color: Colors.white.withValues(alpha: 0.14),
  );

  // Build items: each program + divider + "Create +" at the end
  final items = <PopupMenuEntry<int>>[];
  for (var i = 0; i < schedules.length; i++) {
    final schedule = schedules[i];
    final isCurrent = schedule.localId == currentSchedule.localId;
    items
      ..add(
        PopupMenuItem<int>(
          value: schedule.localId,
          height: 40.h,
          child: Center(
            child: Text(
              schedule.name,
              style: TextStyle(
                color: isCurrent ? colors.accent : white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      )
      ..add(divider);
  }
  // "Create +" action
  items.add(
    PopupMenuItem<int>(
      value: -1,
      height: 40.h,
      child: Center(
        child: Text(
          'Create +',
          style: TextStyle(
            color: white,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );

  final selected = await showMenu<int>(
    context: context,
    position: RelativeRect.fromLTRB(
      offset.dx + 24.w,
      offset.dy + box.size.height - 40.h,
      offset.dx + 220.w,
      0,
    ),
    color: const Color(0xF2202022),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
    elevation: 12,
    items: items,
  );

  if (selected == null || !context.mounted) return;
  if (selected == -1) {
    unawaited(context.push(AppRoutes.scheduleBuilder));
  } else {
    onProgramChanged?.call(selected);
  }
}

// ═══════════════════════════════════════════════════════════════════
// Page dots indicator
// Figma: 8px circles, active = #D2FF00, inactive = glass 0.25
// ═══════════════════════════════════════════════════════════════════
class _PageDots extends StatelessWidget {
  const _PageDots({required this.activeIndex, required this.count});
  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == activeIndex;
        return Container(
          width: 8.w,
          height: 8.w,
          margin: EdgeInsets.only(right: i < count - 1 ? 8.w : 0),
          decoration: BoxDecoration(
            color:
                isActive ? colors.accent : AppColors.of(context).white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
