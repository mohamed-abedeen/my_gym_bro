import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';

import 'muscle_detail_sheet.dart';

import '../../core/database/app_database.dart';
import '../../core/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/app_fonts.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/anatomy_body.dart';
import '../../shared/widgets/liquid_glass_button.dart';
import 'active_session/countdown_screen.dart';
import 'log_bottom_sheet.dart';
import 'status_bottom_sheet.dart';
import 'workout_providers.dart';

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
                colors: isDark
                    ? const [Color(0xFF1A1A1A), Colors.black]
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

        // ── Faded lime glow at bottom ──
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: MediaQuery.of(context).padding.bottom + 5.h,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0x40D2FF00), // lime at ~25% opacity
                    Color(0x00D2FF00), // fully transparent
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header: "Workout" + fire streak + glass menu button
// ═══════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final AppLocalizations l10n;
  const _Header({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
          Icon(
            Icons.local_fire_department,
            color: colors.accent,
            size: 26.sp,
          ),
          SizedBox(width: 2.w),
          Text(
            '2',
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
  final AppLocalizations l10n;
  const _AnatomySection({required this.l10n});

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
  final AppLocalizations l10n;
  const _StatsRow({required this.l10n});

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
  final AppLocalizations l10n;
  const _SessionsLogCard({required this.l10n});

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
                Text(
                  l10n.sessionLog,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
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
  final EnrichedSession enriched;
  const _SessionRow({required this.enriched});

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
  final AppLocalizations l10n;
  const _StatusLogCard({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final stats = ref.watch(weeklyStatsProvider);
    final profile = ref.watch(userProfileProvider);
    final weightUnit = profile.when(
      data: (p) => p?.weightUnit ?? 'kg',
      loading: () => 'kg',
      error: (_, __) => 'kg',
    );

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
                Text(
                  l10n.statusLog,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
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
                        value: '${s.totalVolume.toInt()} $weightUnit',
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
                        value: '${s.avgStrength.toInt()}',
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
  final String label;
  final String value;
  final double? trend;
  final String trendSuffix;

  const _StatLine({
    required this.label,
    required this.value,
    this.trend,
    this.trendSuffix = '',
  });

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
            angle: isPositive ? -1.5708 : 1.5708,
            child: Icon(
              Icons.arrow_forward_rounded,
              color:
                  isPositive
                      ? colors.trendPositive
                      : colors.trendNegative,
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
  final AppLocalizations l10n;
  const _ScheduleCard({required this.l10n});

  @override
  ConsumerState<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends ConsumerState<_ScheduleCard> {
  PageController? _pageController;

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
      orElse: () =>
          schedules.firstWhere((s) => s.isActive, orElse: () => schedules.first),
    );

    // Watch the days for the selected schedule
    final daysAsync = ref.watch(scheduleDaysProvider(selected.localId));
    final allDays = daysAsync.valueOrNull ?? [];
    // Filter out rest days for the card swiper — rest days don't need play/edit.
    // Also check label as fallback for legacy data where isRestDay may not be set.
    final trainingDays = allDays
        .where((d) =>
            !d.isRestDay &&
            !(d.label?.toLowerCase().contains('rest') ?? false))
        .toList();

    // Total pages: training days + "Add Day" card at the end
    final totalPages = trainingDays.length + 1;

    // Auto-advance: determine which training day is next based on completed sessions
    final nextDayAsync = ref.watch(nextTrainingDayIndexProvider(selected.localId));
    final autoPage = nextDayAsync.valueOrNull;

    // Use auto-advance page if the user hasn't manually changed the page yet,
    // otherwise respect the user's persisted page choice.
    final effectivePage = (cardState.currentPage == 0 && autoPage != null)
        ? autoPage
        : cardState.currentPage;
    final safePage = effectivePage.clamp(0, totalPages - 1);

    // Create or recreate PageController at the persisted page
    _pageController?.dispose();
    _pageController = PageController(initialPage: safePage);

    return Column(
      children: [
        SizedBox(
          height: AppSizes.scheduleCardH.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            onPageChanged: (i) {
              ref.read(workoutCardStateProvider.notifier).state =
                  cardState.copyWith(currentPage: i);
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
    ref.read(workoutCardStateProvider.notifier).state =
        WorkoutCardState(selectedScheduleId: scheduleId, currentPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController?.hasClients ?? false) {
        _pageController!.jumpToPage(0);
      }
    });
  }
}

// ── "Add Day" card — shown as the last swipeable page, or alone if no programs ──
class _AddDayCard extends StatelessWidget {
  final AppLocalizations l10n;
  final Schedule? schedule;
  final List<Schedule> allSchedules;
  final ValueChanged<int>? onProgramChanged;

  const _AddDayCard({
    required this.l10n,
    this.schedule,
    this.allSchedules = const [],
    this.onProgramChanged,
  });

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
                  onTap: allSchedules.length > 1 && schedule != null
                      ? () => _showProgramPicker(context, schedule!, allSchedules, onProgramChanged)
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
                onTap: () => context.push(
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
                  child: Icon(Icons.add, color: Colors.black, size: 46.sp),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      AppRadius.scheduleCircle.r,
                    ),
                  ),
                  child: Icon(Icons.search, color: Colors.black, size: 33.sp),
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
  final AppLocalizations l10n;
  final Schedule schedule;
  final ScheduleDay day;
  final List<Schedule> allSchedules;
  final ValueChanged<int> onProgramChanged;

  const _DayCard({
    required this.l10n,
    required this.schedule,
    required this.day,
    required this.allSchedules,
    required this.onProgramChanged,
  });

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
                  onTap: () => _showProgramPicker(
                    context, schedule, allSchedules, onProgramChanged,
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
                onTap: () => _startWorkoutWithCountdown(context, ref, dayLabel),
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
                    color: Colors.black,
                    size: 36.sp,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              // Edit button
              GestureDetector(
                onTap: () => context.push(
                  AppRoutes.scheduleBuilder,
                  extra: schedule.localId,
                ),
                child: Container(
                  width: 69.w,
                  height: 64.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      AppRadius.scheduleCircle.r,
                    ),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: Colors.black,
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

  /// Launch countdown animation → then navigate to active session.
  Future<void> _startWorkoutWithCountdown(
    BuildContext context,
    WidgetRef ref,
    String dayLabel,
  ) async {
    // Get exercise count for the selected day
    final scheduleDao = ref.read(scheduleDaoProvider);
    final exercises = await scheduleDao.getExercises(day.localId);

    if (!context.mounted) return;

    // Show countdown screen as a full-screen modal
    final shouldStart = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder:
            (_, __, ___) => CountdownScreen(
              dayLabel: dayLabel,
              exerciseCount: exercises.length,
              estimatedTime: '1h',
            ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (shouldStart == true && context.mounted) {
      context.push(AppRoutes.activeSession, extra: day.localId);
    }
  }
}

// ── Shared program picker — used by both _DayCard and _AddDayCard ──
void _showProgramPicker(
  BuildContext context,
  Schedule currentSchedule,
  List<Schedule> schedules,
  ValueChanged<int>? onProgramChanged,
) {
  final RenderBox box = context.findRenderObject() as RenderBox;
  final offset = box.localToGlobal(Offset.zero);

  // Build items: each program + divider + "Create +" at the end
  final items = <PopupMenuEntry<int>>[];
  for (var i = 0; i < schedules.length; i++) {
    final schedule = schedules[i];
    final isCurrent = schedule.localId == currentSchedule.localId;
    items.add(PopupMenuItem<int>(
      value: schedule.localId,
      height: 40.h,
      child: Center(
        child: Text(
          schedule.name,
          style: TextStyle(
            color: isCurrent ? const Color(0xFFD2FF00) : Colors.black,
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ));
    items.add(const PopupMenuDivider(height: 1));
  }
  // "Create +" action
  items.add(PopupMenuItem<int>(
    value: -1,
    height: 40.h,
    child: Center(
      child: Text(
        'Create +',
        style: TextStyle(
          color: Colors.black54,
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ));

  showMenu<int>(
    context: context,
    position: RelativeRect.fromLTRB(
      offset.dx + 24.w,
      offset.dy + box.size.height - 40.h,
      offset.dx + 220.w,
      0,
    ),
    color: const Color(0xF2FAFAFA),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
    elevation: 8,
    items: items,
  ).then((selected) {
    if (selected == null) return;
    if (selected == -1) {
      context.push(AppRoutes.scheduleBuilder);
    } else {
      onProgramChanged?.call(selected);
    }
  });
}

// ═══════════════════════════════════════════════════════════════════
// Page dots indicator
// Figma: 8px circles, active = #D2FF00, inactive = glass 0.25
// ═══════════════════════════════════════════════════════════════════
class _PageDots extends StatelessWidget {
  final int activeIndex;
  final int count;
  const _PageDots({required this.activeIndex, required this.count});

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
                isActive
                    ? colors.accent
                    : Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
