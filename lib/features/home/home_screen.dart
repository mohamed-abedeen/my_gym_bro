import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/settings/settings_screen.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/muscle_detail_sheet.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/reports_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';
import 'package:my_gym_bro/shared/widgets/bottom_nav_pill.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';
import 'package:my_gym_bro/shared/widgets/shimmer_box.dart';
import 'package:my_gym_bro/shared/widgets/user_avatar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(l10n: l10n),
        SizedBox(height: 16.h),

        // Trial countdown (Phase 1 deliverable) — only while a trial runs;
        // kBetaFreeAccess nulls the provider so beta builds never see it.
        _TrialBanner(l10n: l10n),

        // Leaderboard card — taps switch to the Bros tab (which hosts the
        // leaderboard) instead of pushing a duplicate copy of the screen.
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(navIndexProvider.notifier).state = 2,
            child: _LeaderboardCard(l10n: l10n),
          ),
        ),
        SizedBox(height: 10.h),

        // Weekly strip
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
          child: _HomeWeeklyStrip(locale: Localizations.localeOf(context)),
        ),
        SizedBox(height: 16.h),

        // "Status" label
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
          child: Text(
            l10n.status,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 36.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: 16.h),

        // Status section — fills whatever height remains and ends clear of
        // the bottom nav. Fixed Figma heights overflowed into the nav on
        // devices with a larger inset-to-height ratio than the design frame.
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSizes.contentPaddingH.w,
              right: AppSizes.contentPaddingH.w,
              bottom: AppSizes.navClearanceOf(context),
            ),
            child: _StatusSection(l10n: l10n),
          ),
        ),
      ],
    );
  }
}

/// Compact frosted banner: "Trial — X days left", tap → paywall. Renders
/// nothing outside a running trial.
class _TrialBanner extends ConsumerWidget {
  const _TrialBanner({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final daysLeft = ref.watch(trialDaysLeftProvider);
    if (daysLeft == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      child: GlassSurface(
        radius: 16.r,
        blurSigma: AppGlass.blurButton,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        onTap: () => context.push(AppRoutes.paywall),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 16.sp, color: colors.accent),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                l10n.trialDaysLeft(daysLeft),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16.sp,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final profile = ref.watch(userProfileProvider);

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10.h,
        left: AppSizes.contentPaddingH.w,
        right: AppSizes.contentPaddingH.w,
      ),
      child: Row(
        children: [
          // "Home" — 36px w700
          Text(
            l10n.tabHome,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 36.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Fire streak (🔥 emoji) — matches the Workout header
          Text('🔥', style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 4.w),
          // Streak count — 24px w700
          Text(
            ref
                .watch(streakProvider)
                .when(
                  data: (s) => '$s',
                  loading: () => '0',
                  error: (_, __) => '0',
                ),
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 12.w),
          // Avatar — 48x48 liquid glass, taps open Account
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            child: LiquidGlassButton(
              width: AppSizes.headerActionBtn.w,
              height: AppSizes.headerActionBtn.w,
              opacity: 0.65,
              radius: 296.r,
              child: UserAvatar(
                size: 44,
                url: profile.valueOrNull?.avatarUrl,
                iconColor: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// L E A D E R B O A R D   C A R D
// Figma: 399x187, bg #1C1C1E, radius 27
// ─────────────────────────────────────────────

class _LeaderboardCard extends ConsumerWidget {
  const _LeaderboardCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final rank = ref.watch(myRankProvider);
    // Other users on the weekly global board — drives the avatar row + count.
    final bros = [
      for (final e
          in ref
                  .watch(leaderboardProvider((
                    scope: LeaderboardScope.global,
                    board: LeaderboardBoard.weekly,
                  )))
                  .valueOrNull ??
              const <LeaderboardEntry>[])
        if (!e.isMe) e,
    ];

    return Container(
      width: double.infinity,
      height: 187.h,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(27.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Right side: the user's rank badge (entry tier until ranked).
          Positioned(
            right: 18.w,
            top: 0,
            bottom: 0,
            child: Center(
              child: RankBadge(
                rank ?? const Rank(RankTier.bronze, 3),
                size: 132.w,
              ),
            ),
          ),

          // Text content (left side)
          Padding(
            padding: EdgeInsets.only(left: 17.w, top: 21.h, bottom: 17.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "The\nLeaderboard" — 32px w700, line-height 31px
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      height: 0.97, // 31/32
                    ),
                    children: [
                      TextSpan(
                        text: 'The\n',
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      TextSpan(
                        text: l10n.leaderboard,
                        style: TextStyle(color: colors.accent),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.h),
                // "Compete with your Gym Bros" — 13px w700
                Text(
                  l10n.competeFriends,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Overlapping avatars — 44x44, stacked with ~38px offset.
                // Real board members once data is in; neutral placeholder
                // circles (and no fake "+N") while offline or empty.
                SizedBox(
                  height: 44.h,
                  child: Stack(
                    children: [
                      if (bros.isEmpty)
                        for (var i = 0; i < 3; i++)
                          _avatarCircle(i * 38.w, colors, null)
                      else ...[
                        for (var i = 0; i < bros.length && i < 3; i++)
                          _avatarCircle(i * 38.w, colors, bros[i].avatarUrl),
                        if (bros.length > 3)
                          Positioned(
                            left: 114.w,
                            child: Container(
                              width: 44.w,
                              height: 44.h,
                              decoration: BoxDecoration(
                                color: colors.overlayBlack,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4.w,
                                  ),
                                  child: FittedBox(
                                    child: Text(
                                      '+${bros.length - 3}',
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _avatarCircle(
    double left,
    AppColorsTheme colors,
    String? avatarUrl,
  ) {
    return Positioned(
      left: left,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.panelBackground, width: 2.w),
        ),
        child: UserAvatar(
          url: avatarUrl,
          size: 40, // UserAvatar applies .w itself; +2w border ×2 ≈ 44w total
          placeholderColor: colors.textSecondary.withValues(alpha: 0.4),
          iconColor: colors.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// W E E K L Y   S T R I P
// Figma: 7 pills 50x74, radius 25, gap ~8px
// Flame icons 15x15 under each day
// ─────────────────────────────────────────────

class _HomeWeeklyStrip extends ConsumerWidget {
  const _HomeWeeklyStrip({required this.locale});
  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekData = ref.watch(weekStripProvider(locale));

    return weekData.when(
      data: (days) => Column(
        children: [
          Row(
            children: days.map((day) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w),
                  child: _HomeDayPill(day: day),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 6.h),
          // Flame emoji under each day — dimmed when no session
          Row(
            children: days.map((day) {
              return Expanded(
                child: SizedBox(
                  height: 15.h,
                  child: Center(
                    child: Opacity(
                      opacity: day.hasSession ? 1.0 : 0.25,
                      child: Text('🔥', style: TextStyle(fontSize: 12.sp)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      loading: () => const _WeekStripSkeleton(),
      error: (_, __) => SizedBox(
        height: 95.h,
        child: Center(
          child: GestureDetector(
            onTap: () => ref.invalidate(weekStripProvider(locale)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  color: AppColors.of(context).textSecondary,
                  size: 16.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  AppLocalizations.of(context).retry,
                  style: TextStyle(
                    color: AppColors.of(context).textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekStripSkeleton extends StatelessWidget {
  const _WeekStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 7 pill skeletons
        Row(
          children: List.generate(
            7,
            (_) => Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.w),
                child: ShimmerBox(
                  width: double.infinity,
                  height: AppSizes.dayPillH.h,
                  borderRadius: BorderRadius.circular(25.r),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 6.h),
        // Flame icon row skeletons
        Row(
          children: List.generate(
            7,
            (_) => Expanded(
              child: Center(
                child: ShimmerBox(
                  width: 15.sp,
                  height: 15.sp,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeDayPill extends StatelessWidget {
  const _HomeDayPill({required this.day});
  final DayData day;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      height: AppSizes.dayPillH.h,
      decoration: BoxDecoration(
        color: day.isToday ? colors.accent : colors.panelBackground,
        borderRadius: BorderRadius.circular(25.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Day abbreviation — 15px w700
          Text(
            day.abbreviation,
            style: TextStyle(
              color: day.isToday ? colors.todayPillText : colors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          // Day number — 24px w700
          Text(
            '${day.dayNumber}',
            style: TextStyle(
              color: day.isToday ? colors.todayPillText : colors.textPrimary,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// S T A T U S   S E C T I O N
// Figma: Left Healing 193x368, Right column:
// Cal Burned 193x64, Next Session 193x64,
// Weekly Progress 193x221
// ─────────────────────────────────────────────

class _StatusSection extends ConsumerWidget {
  const _StatusSection({required this.l10n});
  final AppLocalizations l10n;

  /// "Today" / "Tomorrow" / weekday name for the next scheduled session,
  /// from the active schedule's cycle. "--" without a schedule or while
  /// loading; a session that's due (or a schedule never trained) is Today.
  String _nextSessionLabel(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final schedule = ref.watch(activeScheduleProvider).valueOrNull;
    if (schedule == null) return '--';
    return ref.watch(nextSessionHoursProvider(schedule.localId)).when(
          loading: () => '--',
          error: (_, __) => '--',
          data: (hours) {
            if (hours == null || hours <= 0) return l10n.today;
            final now = DateTime.now();
            final due = now.add(Duration(hours: hours));
            final calendarDays = DateTime(due.year, due.month, due.day)
                .difference(DateTime(now.year, now.month, now.day))
                .inDays;
            if (calendarDays <= 0) return l10n.today;
            if (calendarDays == 1) return l10n.tomorrow;
            return DateFormat.EEEE(
              Localizations.localeOf(context).toString(),
            ).format(due);
          },
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final unit = ref.watch(weightUnitProvider);

    // Height comes from the parent (Expanded in HomeScreen) — 368px on the
    // design frame, shrinking/growing with the space the device actually has.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: Healing card — 193 wide
        Expanded(child: _HealingCard(l10n: l10n)),
        SizedBox(width: 11.w),
        // Right column — 193px wide
        Expanded(
          child: Column(
            children: [
              // Cal Burned — 193x64
              _SmallInfoCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: colors.amber,
                iconSize: 35.sp,
                label: l10n.calBurnedThisWeek,
                value: ref
                    .watch(weeklyCaloriesProvider)
                    .when(
                      data: (cal) => '$cal cal',
                      loading: () => '-- cal',
                      error: (_, __) => '0 cal',
                    ),
              ),
              SizedBox(height: 8.h),
              // Next Session — derived from the active schedule's cycle
              _SmallInfoCard(
                icon: Icons.fitness_center_rounded,
                iconColor: colors.textPrimary,
                iconSize: 38.sp,
                label: l10n.nextSession,
                value: _nextSessionLabel(context, ref, l10n),
              ),
              SizedBox(height: 8.h),
              // Weekly Progress — fills remaining space; taps open Reports
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReportsScreen(),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.r),
                    child: _WeeklyProgressCard(l10n: l10n, unit: unit),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Healing Card — 193x368, radius 24 ──

class _HealingCard extends ConsumerWidget {
  const _HealingCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final muscleStates = ref.watch(muscleRecoveryProvider);
    // "Healing..." only while something is actually recovering; untrained
    // or fully recovered bodies are ready to train.
    final anyHealing = (muscleStates.valueOrNull ?? const [])
        .any((m) => m.state == MuscleState.recovering);

    return GestureDetector(
      onTap: () => showMuscleDetailSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius: BorderRadius.circular(24.r),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Anatomy body — inset on all sides so the sheet never touches
            // the 24.r rounded corners (it used to run edge-to-edge).
            Positioned.fill(
              top: 60.h,
              left: 14.w,
              right: 14.w,
              bottom: 12.h,
              child: LayoutBuilder(
                builder: (context, box) {
                  // The card flexes with screen height — render at the Figma
                  // size (280) when it fits, shrink with the card when not.
                  final bodyH = math.min(box.maxHeight, 280.h);
                  return Opacity(
                    opacity: 0.7,
                    child: muscleStates.when(
                      data: (states) => AnatomyBody(
                        muscleStates: states,
                        height: bodyH,
                        gender: ref.watch(anatomyGenderProvider),
                        basePngPath: ref.watch(activeSkinPathProvider),
                      ),
                      loading: () => ShimmerBox(
                        width: double.infinity,
                        height: bodyH,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      error: (_, __) => AnatomyBody(
                        muscleStates: const [],
                        height: bodyH,
                        gender: ref.watch(anatomyGenderProvider),
                        basePngPath: ref.watch(activeSkinPathProvider),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Text overlay — centered, 32px title per Figma
            Positioned(
              left: 8.w,
              right: 8.w,
              top: 15.h,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Healing..." / "Ready" — scales down to stay on one line
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      anyHealing ? l10n.healingTitle : l10n.readyTitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Subtitle — max 2 lines before ellipsis
                  Text(
                    anyHealing ? l10n.healingSubtitle : l10n.readySubtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
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

// ── Small Info Card — 193x64, radius 24 ──

class _SmallInfoCard extends StatelessWidget {
  const _SmallInfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.iconSize = 35,
  });
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      height: 58.h,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(24.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: iconSize),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Label — 10px w400
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                // Value — 16px w510
                Text(
                  value,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly Progress Card — 193x221, radius 24 ──

class _WeeklyProgressCard extends ConsumerWidget {
  const _WeeklyProgressCard({required this.l10n, required this.unit});
  final AppLocalizations l10n;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final stats = ref.watch(weeklyStatsProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(24.r),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      child: stats.when(
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Weekly Progress"
            Text(
              l10n.weeklyProgress,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 2.h),
            // Volume
            _StatRow(
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
            // Total Duration
            _StatRow(
              label: l10n.totalDuration,
              value: s.formattedDuration,
              trend: s.durationTrend,
              trendSuffix: '%',
            ),
            SizedBox(height: 2.h),
            // Avg Strength
            _StatRow(
              label: l10n.avgStrength,
              value: '${s.avgStrength.toInt()}',
              trend: s.strengthTrend,
              trendPrefix: s.strengthTrend != null && s.strengthTrend! > 0
                  ? ''
                  : '',
              isPositiveTrend: s.strengthTrend == null || s.strengthTrend! >= 0,
            ),
            SizedBox(height: 2.h),
            // Records
            _StatRow(
              label: l10n.records,
              value: ref
                  .watch(recordsProvider)
                  .when(
                    data: (r) => '${r.count}',
                    loading: () => '--',
                    error: (_, __) => '0',
                  ),
            ),
          ],
        ),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: colors.accent,
            strokeWidth: 2.w,
          ),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.trend,
    this.trendPrefix = '',
    this.trendSuffix = '',
    this.isPositiveTrend = true,
  });
  final String label;
  final String value;
  final double? trend;
  final String trendPrefix;
  final String trendSuffix;
  final bool isPositiveTrend;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trendColor = isPositiveTrend
        ? colors.trendPositive
        : colors.trendNegative;
    final hasTrend = trend != null;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              // Value
              Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (hasTrend)
          Text(
            '$trendPrefix${trend!.toInt()}$trendSuffix',
            style: TextStyle(
              color: trendColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        // Arrow icon — 24x24, rotated -90deg for up-right
        Padding(
          padding: EdgeInsets.only(left: 2.w),
          child: Transform.rotate(
            angle: isPositiveTrend ? AppAngles.quarterTurnCcw : 0,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: hasTrend ? trendColor : colors.trendPositive,
              size: 24.sp,
            ),
          ),
        ),
      ],
    );
  }
}
