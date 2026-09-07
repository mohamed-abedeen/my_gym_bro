import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/schedule/share/routine_share_sheet.dart';
import 'package:my_gym_bro/features/schedule/split_providers.dart';
import 'package:my_gym_bro/features/schedule/split_widgets.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Split Overview — full-screen view of the active split: title block, the
/// "next up" card, a 2×2 stats grid, the reorderable weekly day list (→ Day
/// Detail) and quick actions (edit, share, → Discover). Entry: the grid
/// button on the Workout card.
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

    // The next-up training day drives the card and the row dot.
    final nextIdx =
        ref.watch(nextTrainingDayIndexProvider(schedule.localId)).valueOrNull ??
            0;
    final nextDay = (trainingDays.isNotEmpty && nextIdx < trainingDays.length)
        ? trainingDays[nextIdx]
        : null;
    // Positional day number (1…N over every day, rest included).
    final nextNumber = nextDay == null
        ? 0
        : allDays.indexWhere((d) => d.localId == nextDay.localId) + 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
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
          SizedBox(height: 22.h),
          // ── Title block ──
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.contentPaddingH.w,
            ),
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
              ],
            ),
          ),
          if (nextDay != null) ...[
            SizedBox(height: 18.h),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.contentPaddingH.w,
              ),
              child: _NextUpCard(
                l10n: l10n,
                day: nextDay,
                dayNumber: nextNumber,
              ),
            ),
          ],
          SizedBox(height: 14.h),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
            child: _StatsGrid(l10n: l10n, schedule: schedule),
          ),
          SizedBox(height: 14.h),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
            child: _WeeklyPlanCard(
              l10n: l10n,
              scheduleId: schedule.localId,
              days: allDays,
              nextDayId: nextDay?.localId,
            ),
          ),
          SizedBox(height: 14.h),
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

/// Zero-width space: a line-break opportunity after each slash in the plan
/// title. Built from the code point so the source stays ASCII — an inline
/// U+200B is invisible and trips hidden-Unicode warnings in review.
final _zwsp = String.fromCharCode(0x200B);

/// Plan title with every `/` separator rendered in the accent color. A
/// zero-width space after each slash lets long names like
/// "Push/Pull/Legs/Upper/Lower" wrap there instead of overflowing.
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
              TextSpan(
                text: '/$_zwsp',
                style: TextStyle(color: colors.accent),
              ),
            TextSpan(text: parts[i]),
          ],
        ],
      ),
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 34.sp,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
    );
  }
}

// ── Next up: the upcoming training day at a glance ──
class _NextUpCard extends ConsumerWidget {
  const _NextUpCard({
    required this.l10n,
    required this.day,
    required this.dayNumber,
  });
  final AppLocalizations l10n;
  final ScheduleDay day;

  /// 1-based position of [day] in the full plan.
  final int dayNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final exercises =
        ref.watch(dayExercisesProvider(day.localId)).valueOrNull ??
            const <DayExercise>[];
    final muscles = dayMuscleGroups(exercises);
    final name = day.label ?? l10n.dayNumber(dayNumber);
    final (mn, mx) = estimateSessionMinutes(exercises.length);
    void open() => context.push(AppRoutes.dayDetail, extra: day.localId);

    return GestureDetector(
      onTap: open,
      child: Container(
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius: BorderRadius.circular(24.r),
        ),
        padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.splitNextUp(dayNumber).toUpperCase(),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        muscles.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.subtitleText,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 14.w),
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.separator),
                  ),
                  child: Icon(
                    splitDayIcon(muscles),
                    size: 26.sp,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            // IntrinsicHeight bounds the row so the Open button can stretch
            // to the chips' height (plain stretch would be unbounded here).
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _NextUpChip(
                      value: l10n.premadeExercisesCount(exercises.length),
                      label: l10n.splitPlanned,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _NextUpChip(
                      value: l10n.splitMinutesRange(mn, mx),
                      label: l10n.splitEstimated,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: open,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20.sp,
                            color: colors.todayPillText,
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            l10n.splitOpen,
                            style: TextStyle(
                              color: colors.todayPillText,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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

class _NextUpChip extends StatelessWidget {
  const _NextUpChip({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textSecondary, fontSize: 11.5.sp),
          ),
        ],
      ),
    );
  }
}

// ── Stats grid (2×2): Duration · Days / Session · Progress ──
class _StatsGrid extends ConsumerWidget {
  const _StatsGrid({required this.l10n, required this.schedule});
  final AppLocalizations l10n;
  final Schedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final created = schedule.createdAt;
    final weeks =
        created == null ? 0 : DateTime.now().difference(created).inDays ~/ 7;
    final allDays =
        ref.watch(scheduleDaysProvider(schedule.localId)).valueOrNull ?? [];
    final trainingCount = allDays.where((d) => !isRestScheduleDay(d)).length;
    final restCount = allDays.length - trainingCount;
    final minutes =
        ref.watch(scheduleSessionMinutesProvider(schedule.localId)).valueOrNull;
    final progress =
        ref.watch(scheduleCycleProgressProvider(schedule.localId)).valueOrNull ??
            0.0;

    Widget row(Widget left, Widget right) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              SizedBox(width: 10.w),
              Expanded(child: right),
            ],
          ),
        );

    return Column(
      children: [
        row(
          _StatTile(
            icon: Icons.calendar_month_rounded,
            label: l10n.splitStatDuration,
            value: l10n.weeksCount(weeks < 1 ? 1 : weeks),
            sub: l10n.splitStatSinceStart,
          ),
          _StatTile(
            icon: Icons.date_range_rounded,
            label: l10n.splitStatDays,
            value: '$trainingCount / ${l10n.week}',
            sub: l10n.splitRestDaysCount(restCount),
          ),
        ),
        SizedBox(height: 10.h),
        row(
          _StatTile(
            icon: Icons.schedule_rounded,
            label: l10n.splitStatSession,
            value: minutes == null
                ? '—'
                : l10n.splitMinutesRange(minutes.$1, minutes.$2),
            sub: l10n.splitStatAvgDuration,
          ),
          _StatTile(
            icon: Icons.trending_up_rounded,
            label: l10n.splitStatProgress,
            value: '${(progress * 100).round()}%',
            progress: progress,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16.sp, color: colors.textSecondary),
              SizedBox(width: 5.w),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          SizedBox(height: 6.h),
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
              style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
            ),
        ],
      ),
    );
  }
}

// ── Weekly plan: one reorderable row per schedule day, rest days included ──
class _WeeklyPlanCard extends ConsumerStatefulWidget {
  const _WeeklyPlanCard({
    required this.l10n,
    required this.scheduleId,
    required this.days,
    required this.nextDayId,
  });
  final AppLocalizations l10n;
  final int scheduleId;
  final List<ScheduleDay> days;
  final int? nextDayId;

  @override
  ConsumerState<_WeeklyPlanCard> createState() => _WeeklyPlanCardState();
}

class _WeeklyPlanCardState extends ConsumerState<_WeeklyPlanCard> {
  /// Local order so a drop lands instantly; replaced whenever the Drift
  /// stream hands us a new list (after our own write, or an edit elsewhere).
  late List<ScheduleDay> _days = widget.days;

  @override
  void didUpdateWidget(_WeeklyPlanCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.days, widget.days)) _days = widget.days;
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    // ReorderableListView reports the insertion slot, which is one past
    // the target when moving down.
    final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (oldIndex == to) return;
    final next = List<ScheduleDay>.of(_days);
    next.insert(to, next.removeAt(oldIndex));
    setState(() => _days = next);
    await ref
        .read(scheduleDaoProvider)
        .reorderDays([for (final d in next) d.localId]);
    if (mounted) _refreshDerived();
  }

  Future<void> _addRestDay() async {
    unawaited(HapticFeedback.selectionClick());
    await ref.read(scheduleDaoProvider).addRestDay(widget.scheduleId);
    if (mounted) _refreshDerived();
  }

  /// `scheduleDaysProvider` is a stream and updates itself; the day-derived
  /// futures don't watch the DB, so nudge them after a write.
  void _refreshDerived() {
    ref
      ..invalidate(nextTrainingDayIndexProvider(widget.scheduleId))
      ..invalidate(scheduleSessionMinutesProvider(widget.scheduleId))
      ..invalidate(scheduleCycleProgressProvider(widget.scheduleId));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = widget.l10n;

    return Container(
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(24.r),
      ),
      padding: EdgeInsets.fromLTRB(12.w, 18.h, 12.w, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(6.w, 0, 6.w, 4.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.splitWeeklyPlan,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 13.sp,
                  color: colors.textSecondary,
                ),
                SizedBox(width: 4.w),
                Text(
                  l10n.splitReorderHint,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          // Handle-only drag (buildDefaultDragHandles off) so a plain tap on
          // a row still opens Day Detail.
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            itemCount: _days.length,
            onReorderStart: (_) => HapticFeedback.selectionClick(),
            onReorder: _onReorder,
            proxyDecorator: (_, index, __) => Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.92,
                child: _WeeklyDayRow(
                  l10n: l10n,
                  index: index,
                  day: _days[index],
                  isNext: _days[index].localId == widget.nextDayId,
                  dragging: true,
                ),
              ),
            ),
            itemBuilder: (context, i) => Padding(
              key: ValueKey(_days[i].localId),
              padding: EdgeInsets.only(bottom: 8.h),
              child: _WeeklyDayRow(
                l10n: l10n,
                index: i,
                day: _days[i],
                isNext: _days[i].localId == widget.nextDayId,
              ),
            ),
          ),
          _AddRestDayRow(l10n: l10n, onTap: _addRestDay),
        ],
      ),
    );
  }
}

class _WeeklyDayRow extends ConsumerWidget {
  const _WeeklyDayRow({
    required this.l10n,
    required this.index,
    required this.day,
    required this.isNext,
    this.dragging = false,
  });
  final AppLocalizations l10n;

  /// Position in the plan — day numbers are positional, so they re-label
  /// 1…N after a reorder.
  final int index;
  final ScheduleDay day;
  final bool isNext;

  /// Accent outline for the floating copy while it's being dragged.
  final bool dragging;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isRest = isRestScheduleDay(day);
    final exercises = isRest
        ? const <DayExercise>[]
        : ref.watch(dayExercisesProvider(day.localId)).valueOrNull ??
            const <DayExercise>[];
    final muscles = dayMuscleGroups(exercises);
    final number = index + 1;
    final name = isRest
        ? l10n.dayNumber(number)
        : day.label ?? l10n.dayNumber(number);

    return GestureDetector(
      onTap: isRest
          ? null
          : () => context.push(AppRoutes.dayDetail, extra: day.localId),
      child: Container(
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: dragging ? colors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 8.w, 12.h),
        child: Row(
          children: [
            // Day index column
            SizedBox(
              width: 44.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$number',
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
            if (!isRest)
              Padding(
                padding: EdgeInsets.only(left: 8.w),
                child: Column(
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
              ),
            SizedBox(width: 2.w),
            // Drag handle — the only place a drag can start.
            ReorderableDragStartListener(
              index: index,
              child: SizedBox(
                width: 36.w,
                height: 44.h,
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 22.sp,
                  color: colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed "+ Add rest day" affordance under the last row.
class _AddRestDayRow extends StatelessWidget {
  const _AddRestDayRow({required this.l10n, required this.onTap});
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: colors.separator,
          radius: 18.r,
          strokeWidth: 1.5,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18.sp, color: colors.textSecondary),
              SizedBox(width: 6.w),
              Text(
                l10n.splitAddRestDay,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded outline — Flutter's [Border] has no dashed style.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });
  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    // Inset half the stroke so the line isn't clipped at the edges.
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

// ── Actions: Edit plan · Share · Discover (accent) ──
class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.l10n, required this.schedule});
  final AppLocalizations l10n;
  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight keeps the three tiles the same height when a title
    // wraps in a longer locale.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickTile(
              icon: Icons.edit_calendar_rounded,
              title: l10n.splitQuickEditPlan,
              onTap: () => context.push(
                AppRoutes.scheduleBuilder,
                extra: schedule.localId,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _QuickTile(
              icon: Icons.ios_share_rounded,
              title: l10n.splitQuickShare,
              onTap: () => showRoutineShareSheet(
                context,
                scheduleId: schedule.localId,
                title: schedule.name.trim().isEmpty
                    ? l10n.shareRoutineDefaultTitle
                    : schedule.name,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _QuickTile(
              icon: Icons.grid_view_rounded,
              title: l10n.splitQuickDiscover,
              accent: true,
              onTap: () => context.push(AppRoutes.discoverPrograms),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.accent = false,
  });
  final IconData icon;
  final String title;
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22.sp, color: fg),
            SizedBox(height: 8.h),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 13.5.sp,
                fontWeight: accent ? FontWeight.w800 : FontWeight.w700,
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
