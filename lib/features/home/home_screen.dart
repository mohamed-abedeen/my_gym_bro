import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/anatomy_body.dart';
import '../../shared/widgets/liquid_glass_button.dart';
import '../settings/settings_screen.dart';
import '../workout/muscle_detail_sheet.dart';
import '../workout/workout_providers.dart';

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

        // Leaderboard card
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
          child: _LeaderboardCard(l10n: l10n),
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

        // Status section
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
          child: _StatusSection(l10n: l10n),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  final AppLocalizations l10n;
  const _Header({required this.l10n});

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
          // Flame icon — 26x26, orange per Figma
          Icon(
            Icons.local_fire_department_rounded,
            color: colors.amber,
            size: 26.sp,
          ),
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
            onTap:
                () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsScreen()),
                ),
            child: LiquidGlassButton(
              width: 48.w,
              height: 48.h,
              opacity: 0.65,
              radius: 296.r,
              child: profile.when(
                data:
                    (p) =>
                        p?.avatarUrl != null
                            ? ClipOval(
                              child: Image.network(
                                p!.avatarUrl!,
                                width: 44.w,
                                height: 44.h,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => Icon(
                                      Icons.person_rounded,
                                      color: colors.textPrimary,
                                      size: 28.sp,
                                    ),
                              ),
                            )
                            : Icon(
                              Icons.person_rounded,
                              color: colors.textPrimary,
                              size: 28.sp,
                            ),
                loading:
                    () => Icon(
                      Icons.person_rounded,
                      color: colors.textPrimary,
                      size: 28.sp,
                    ),
                error:
                    (_, __) => Icon(
                      Icons.person_rounded,
                      color: colors.textPrimary,
                      size: 28.sp,
                    ),
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

class _LeaderboardCard extends StatelessWidget {
  final AppLocalizations l10n;
  const _LeaderboardCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
          // Dumbbell image (right side) — Figma: 258x250, right-aligned
          Positioned(
            right: -30.w,
            top: -30.h,
            child: Image.asset(
              'assets/images/dumbbells.png',
              width: 258.w,
              height: 250.h,
              fit: BoxFit.cover,
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
                        text: 'Leaderboard',
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
                // Overlapping friend avatars — 44x44, stacked with ~38px offset
                SizedBox(
                  height: 44.h,
                  child: Stack(
                    children: [
                      // Avatar 1 at left: 0
                      _avatarCircle(0, colors),
                      // Avatar 2 at left: 38
                      _avatarCircle(38.w, colors),
                      // Avatar 3 at left: 76
                      _avatarCircle(76.w, colors),
                      // "+4" badge at left: 114
                      Positioned(
                        left: 114.w,
                        child: Container(
                          width: 44.w,
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '+4',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
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
          ),
        ],
      ),
    );
  }

  static Widget _avatarCircle(double left, AppColorsTheme colors) {
    return Positioned(
      left: left,
      child: Container(
        width: 44.w,
        height: 44.h,
        decoration: BoxDecoration(
          color: colors.textSecondary.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(color: colors.panelBackground, width: 2.w),
        ),
        child: Icon(
          Icons.person_rounded,
          color: colors.textSecondary,
          size: 24.sp,
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
  final Locale locale;
  const _HomeWeeklyStrip({required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final flameColor = isDark ? colors.accent : colors.amber;
    final weekData = ref.watch(weekStripProvider(locale));

    return weekData.when(
      data:
          (days) => Column(
            children: [
              Row(
                children:
                    days.map((day) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.w),
                          child: _HomeDayPill(day: day),
                        ),
                      );
                    }).toList(),
              ),
              SizedBox(height: 6.h),
              // Flame icons under each day
              Row(
                children:
                    days.map((day) {
                      return Expanded(
                        child: SizedBox(
                          height: 15.h,
                          child: Center(
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              color:
                                  day.hasSession
                                      ? flameColor
                                      : flameColor.withValues(
                                        alpha: 0.25,
                                      ),
                              size: 15.sp,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
      loading: () => SizedBox(height: 95.h),
      error: (_, __) => SizedBox(height: 95.h),
    );
  }
}

class _HomeDayPill extends StatelessWidget {
  final DayData day;
  const _HomeDayPill({required this.day});

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
              color: day.isToday ? Colors.black : colors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          // Day number — 24px w700
          Text(
            '${day.dayNumber}',
            style: TextStyle(
              color: day.isToday ? Colors.black : colors.textPrimary,
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
  final AppLocalizations l10n;
  const _StatusSection({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final profile = ref.watch(userProfileProvider);
    final weightUnit = profile.when(
      data: (p) => p?.weightUnit ?? 'kg',
      loading: () => 'kg',
      error: (_, __) => 'kg',
    );

    // Fixed height from Figma: 368px
    return SizedBox(
      height: 368.h,
      child: Row(
        children: [
          // Left: Healing card — 193x368
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
                  label: l10n.calBurnedLastWeek,
                  value: ref
                      .watch(weeklyCaloriesProvider)
                      .when(
                        data: (cal) => '$cal cal',
                        loading: () => '-- cal',
                        error: (_, __) => '0 cal',
                      ),
                ),
                SizedBox(height: 8.h),
                // Next Session
                _SmallInfoCard(
                  icon: Icons.fitness_center_rounded,
                  iconColor: colors.textPrimary,
                  iconSize: 38.sp,
                  label: l10n.nextSession,
                  value: l10n.tomorrow,
                ),
                SizedBox(height: 8.h),
                // Weekly Progress — fills remaining space
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.r),
                    child: _WeeklyProgressCard(
                      l10n: l10n,
                      weightUnit: weightUnit,
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
}

// ── Healing Card — 193x368, radius 24 ──

class _HealingCard extends ConsumerWidget {
  final AppLocalizations l10n;
  const _HealingCard({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final muscleStates = ref.watch(muscleRecoveryProvider);

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
            // Anatomy body — scaled to fit card
            Positioned.fill(
              top: 60.h,
              child: Opacity(
                opacity: 0.7,
                child: muscleStates.when(
                  data:
                      (states) => AnatomyBody(
                        muscleStates: states,
                        height: 280.h,
                        gender: ref.watch(anatomyGenderProvider),
                      ),
                  loading: () => const SizedBox.shrink(),
                  error:
                      (_, __) => AnatomyBody(
                        muscleStates: const [],
                        height: 280.h,
                        gender: ref.watch(anatomyGenderProvider),
                      ),
                ),
              ),
            ),
            // Text overlay — centered, 32px title per Figma
            Positioned(
              left: 0,
              right: 0,
              top: 15.h,
              child: Column(
                children: [
                  // "Healing..." — 32px w700 centered
                  Text(
                    l10n.healingTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // "Your body needs some rest" — 10px w400 centered
                  Text(
                    l10n.healingSubtitle,
                    textAlign: TextAlign.center,
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
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String label;
  final String value;

  const _SmallInfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.iconSize = 35,
  });

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
  final AppLocalizations l10n;
  final String weightUnit;
  const _WeeklyProgressCard({required this.l10n, required this.weightUnit});

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
        data:
            (s) => Column(
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
                  value: '${s.totalVolume.toInt()}  $weightUnit',
                  trend: s.volumeTrend,
                  isPositiveTrend: true,
                ),
                SizedBox(height: 2.h),
                // Total Duration
                _StatRow(
                  label: l10n.totalDuration,
                  value: s.formattedDuration,
                  trend: s.durationTrend,
                  trendSuffix: '%',
                  isPositiveTrend: true,
                ),
                SizedBox(height: 2.h),
                // Avg Strength
                _StatRow(
                  label: l10n.avgStrength,
                  value: '${s.avgStrength.toInt()}',
                  trend: s.strengthTrend,
                  trendPrefix:
                      s.strengthTrend != null && s.strengthTrend! > 0 ? '' : '',
                  isPositiveTrend:
                      s.strengthTrend == null || s.strengthTrend! >= 0,
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
        loading:
            () => Center(
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
  final String label;
  final String value;
  final double? trend;
  final String trendPrefix;
  final String trendSuffix;
  final bool isPositiveTrend;

  const _StatRow({
    required this.label,
    required this.value,
    this.trend,
    this.trendPrefix = '',
    this.trendSuffix = '',
    this.isPositiveTrend = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trendColor =
        isPositiveTrend ? colors.trendPositive : colors.trendNegative;
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
            angle: isPositiveTrend ? -1.5708 : 0, // -90deg or 0
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
