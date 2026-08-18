import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/schedule/split_providers.dart';
import 'package:my_gym_bro/features/schedule/split_widgets.dart';
import 'package:my_gym_bro/features/workout/status_bottom_sheet.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Split Overview — full-screen view of the active split: anatomy hero,
/// plan stats, the weekly day list (→ Day Detail) and quick links (→
/// Discover, edit, settings). Entry: the grid button on the Workout card.
class SplitOverviewScreen extends ConsumerWidget {
  const SplitOverviewScreen({this.scheduleId, super.key});

  /// Schedule to show; falls back to the selected/active one.
  final int? scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    final schedules = ref.watch(allSchedulesProvider).valueOrNull ?? [];
    final selectedId =
        scheduleId ?? ref.watch(workoutCardStateProvider).selectedScheduleId;
    Schedule? schedule;
    for (final s in schedules) {
      if (s.localId == selectedId) {
        schedule = s;
        break;
      }
    }
    if (schedule == null) {
      for (final s in schedules) {
        if (s.isActive) {
          schedule = s;
          break;
        }
      }
    }
    if (schedule == null && schedules.isNotEmpty) schedule = schedules.first;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: schedule == null
            ? _EmptyState(l10n: l10n)
            : _OverviewBody(l10n: l10n, schedule: schedule),
      ),
    );
  }
}

/// No plan yet → header + a Discover CTA so the screen still leads somewhere.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.contentPaddingH.w,
            8.h,
            AppSizes.contentPaddingH.w,
            0,
          ),
          child: SplitHeaderButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
          child: _DiscoverCta(l10n: l10n),
        ),
        const Spacer(),
      ],
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({required this.l10n, required this.schedule});
  final AppLocalizations l10n;
  final Schedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final allDays =
        ref.watch(scheduleDaysProvider(schedule.localId)).valueOrNull ?? [];
    final trainingDays =
        allDays.where((d) => !isRestScheduleDay(d)).toList();

    // The next-up training day drives the hero muscles and the row dot.
    final nextIdx =
        ref.watch(nextTrainingDayIndexProvider(schedule.localId)).valueOrNull ??
            0;
    final nextDay = (trainingDays.isNotEmpty && nextIdx < trainingDays.length)
        ? trainingDays[nextIdx]
        : null;
    final heroMuscles = nextDay == null
        ? const <String>[]
        : dayMuscleGroups(
            ref.watch(dayExercisesProvider(nextDay.localId)).valueOrNull ??
                const [],
          );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero: anatomy behind header + title block ──
          // Clip.none lets the body flow under the stats card below.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                right: -20.w,
                child: SplitHeroBody(muscles: heroMuscles),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.contentPaddingH.w,
                      8.h,
                      AppSizes.contentPaddingH.w,
                      0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SplitHeaderButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        SplitHeaderButton(
                          icon: Icons.edit_rounded,
                          onTap: () => context.push(
                            AppRoutes.scheduleBuilder,
                            extra: schedule.localId,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 28.h),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSizes.contentPaddingH.w,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 260.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.splitCurrentPlan.toUpperCase(),
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          _AccentSlashTitle(name: schedule.name),
                          SizedBox(height: 8.h),
                          Text(
                            l10n.splitTrainingDaysPerWeek(trainingDays.length),
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            l10n.splitDescription,
                            style: TextStyle(
                              color: colors.subtitleText,
                              fontSize: 14.sp,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
            child: _StatsStrip(l10n: l10n, schedule: schedule),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
            child: _WeeklyPlanCard(
              l10n: l10n,
              days: allDays,
              nextDayId: nextDay?.localId,
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
            child: _QuickLinks(l10n: l10n, schedule: schedule),
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }
}

/// Plan title with every `/` separator rendered in the accent color.
class _AccentSlashTitle extends StatelessWidget {
  const _AccentSlashTitle({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final parts = name.split('/');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0)
              TextSpan(text: '/', style: TextStyle(color: colors.accent)),
            TextSpan(text: parts[i]),
          ],
        ],
      ),
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 38.sp,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
    );
  }
}

// ── Stats strip: Duration · Days · Session · Progress ──
class _StatsStrip extends ConsumerWidget {
  const _StatsStrip({required this.l10n, required this.schedule});
  final AppLocalizations l10n;
  final Schedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    final created = schedule.createdAt;
    final weeks =
        created == null ? 0 : DateTime.now().difference(created).inDays ~/ 7;
    final allDays =
        ref.watch(scheduleDaysProvider(schedule.localId)).valueOrNull ?? [];
    final trainingCount = allDays.where((d) => !isRestScheduleDay(d)).length;
    final minutes =
        ref.watch(scheduleSessionMinutesProvider(schedule.localId)).valueOrNull;
    final progress =
        ref.watch(scheduleCycleProgressProvider(schedule.localId)).valueOrNull ??
            0.0;

    Widget separator() => Container(
          width: 1.w,
          height: 44.h,
          color: colors.cardElevated,
        );

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
      ),
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        children: [
          _StatColumn(
            icon: Icons.calendar_month_rounded,
            label: l10n.splitStatDuration,
            value: l10n.weeksCount(weeks < 1 ? 1 : weeks),
            sub: l10n.splitStatSinceStart,
          ),
          separator(),
          _StatColumn(
            icon: Icons.date_range_rounded,
            label: l10n.splitStatDays,
            value: '$trainingCount / ${l10n.week}',
            sub: l10n.splitStatTrainingDays,
          ),
          separator(),
          _StatColumn(
            icon: Icons.schedule_rounded,
            label: l10n.splitStatSession,
            value: minutes == null
                ? '—'
                : l10n.splitMinutesRange(minutes.$1, minutes.$2),
            sub: l10n.splitStatAvgDuration,
          ),
          separator(),
          _StatColumn(
            icon: Icons.trending_up_rounded,
            label: l10n.splitStatProgress,
            value: '${(progress * 100).round()}%',
            progress: progress,
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.progress,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  /// When set, a 0..1 progress bar replaces the sub line.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15.sp, color: colors.textSecondary),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            // Scale down instead of truncating — ranges like "45–75 min."
            // must stay readable in a quarter-width column.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 4.h),
            if (progress != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(3.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5.h,
                  backgroundColor: colors.textPrimary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(colors.accent),
                ),
              )
            else if (sub != null)
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.5.sp,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Weekly plan: one row per schedule day ──
class _WeeklyPlanCard extends StatelessWidget {
  const _WeeklyPlanCard({
    required this.l10n,
    required this.days,
    required this.nextDayId,
  });
  final AppLocalizations l10n;
  final List<ScheduleDay> days;
  final int? nextDayId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
      ),
      padding: EdgeInsets.fromLTRB(12.w, 18.h, 12.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 6.w, bottom: 12.h),
            child: Text(
              l10n.splitWeeklyPlan,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final day in days) ...[
            _WeeklyDayRow(
              l10n: l10n,
              day: day,
              isNext: day.localId == nextDayId,
            ),
            if (day != days.last) SizedBox(height: 8.h),
          ],
        ],
      ),
    );
  }
}

class _WeeklyDayRow extends ConsumerWidget {
  const _WeeklyDayRow({
    required this.l10n,
    required this.day,
    required this.isNext,
  });
  final AppLocalizations l10n;
  final ScheduleDay day;
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isRest = isRestScheduleDay(day);
    final exercises = isRest
        ? const <DayExercise>[]
        : ref.watch(dayExercisesProvider(day.localId)).valueOrNull ??
            const <DayExercise>[];
    final muscles = dayMuscleGroups(exercises);
    final name = day.label ?? l10n.dayNumber(day.dayIndex + 1);

    return GestureDetector(
      onTap: isRest
          ? null
          : () => context.push(AppRoutes.dayDetail, extra: day.localId),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(18.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        child: Row(
          children: [
            // Day index column
            SizedBox(
              width: 44.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${day.dayIndex + 1}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        l10n.splitDay,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                      if (isNext) ...[
                        SizedBox(width: 4.w),
                        Container(
                          width: 5.w,
                          height: 5.w,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Day-type icon circle
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.separator),
              ),
              child: Icon(
                isRest ? Icons.bedtime_rounded : splitDayIcon(muscles),
                size: 22.sp,
                color: isRest ? colors.subtitleText : colors.accent,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    isRest ? l10n.splitRestSubtitle : muscles.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (!isRest) ...[
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.premadeExercisesCount(exercises.length),
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (exercises.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Builder(
                      builder: (_) {
                        final (mn, mx) =
                            estimateSessionMinutes(exercises.length);
                        return Text(
                          l10n.splitMinutesRange(mn, mx),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12.sp,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: colors.grey,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Quick links: 2×2 grid, Discover tile in accent ──
class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.l10n, required this.schedule});
  final AppLocalizations l10n;
  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.bar_chart_rounded,
                title: l10n.splitQuickProgress,
                subtitle: l10n.splitQuickProgressSub,
                onTap: () => showStatusBottomSheet(context),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _QuickTile(
                icon: Icons.edit_calendar_rounded,
                title: l10n.splitQuickEditPlan,
                subtitle: l10n.splitQuickEditPlanSub,
                onTap: () => context.push(
                  AppRoutes.scheduleBuilder,
                  extra: schedule.localId,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.settings_rounded,
                title: l10n.splitQuickSettings,
                subtitle: l10n.splitQuickSettingsSub,
                onTap: () => context.push(AppRoutes.settings),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _QuickTile(
                icon: Icons.grid_view_rounded,
                title: l10n.splitQuickDiscover,
                subtitle: l10n.splitQuickDiscoverSub,
                accent: true,
                onTap: () => context.push(AppRoutes.discoverPrograms),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fg = accent ? colors.todayPillText : colors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: accent ? colors.accent : colors.panelBackground,
          borderRadius: BorderRadius.circular(20.r),
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 24.sp, color: fg),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20.sp,
                  color: accent ? fg : colors.grey,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 14.5.sp,
                fontWeight: accent ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent
                    ? fg.withValues(alpha: 0.65)
                    : colors.subtitleText,
                fontSize: 11.5.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width accent CTA used by the empty state.
class _DiscoverCta extends StatelessWidget {
  const _DiscoverCta({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () => context.push(AppRoutes.discoverPrograms),
      child: Container(
        height: 60.h,
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(22.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Row(
          children: [
            Icon(Icons.grid_view_rounded,
                size: 24.sp, color: colors.todayPillText),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                l10n.discoverOtherPlansCta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.todayPillText,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 24.sp, color: colors.todayPillText),
          ],
        ),
      ),
    );
  }
}
