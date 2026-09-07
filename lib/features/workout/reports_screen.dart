import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/settings/app_settings_provider.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Full-screen "Reports" view opened from the Weekly Reports card in the
/// Status sheet. A week navigator (‹ date range › + calendar picker) and a
/// row of day circles drive a per-day report: weights (this vs last week),
/// calories burned, and duration — all broken down per exercise for the
/// selected day. Rest days show the week's totals instead.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Unselected chip fill — a faint accent wash over the elevated card (the
/// olive look in the mock).
Color _chipColor(AppColorsTheme colors) =>
    Color.alphaBlend(colors.accent.withValues(alpha: 0.13), colors.cardElevated);

/// "Friday, Sep 4" — full weekday + short month/day, each part localized.
String _longDay(DateTime d, Locale locale) =>
    '${DateFormat.EEEE(locale.languageCode).format(d)}, '
    '${DateFormat.MMMd(locale.languageCode).format(d)}';

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _weekStart; // Monday midnight
  late DateTime _selectedDay; // midnight

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = _mondayOf(now);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  void _selectWeek(DateTime monday) {
    setState(() {
      _weekStart = monday;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      // Keep today selected when picking the current week, else the Monday.
      final inWeek =
          !today.isBefore(monday) &&
          today.isBefore(monday.add(const Duration(days: 7)));
      _selectedDay = inWeek ? today : monday;
    });
  }

  DateTime _shiftedWeek(int weeks) => DateTime(
    _weekStart.year,
    _weekStart.month,
    _weekStart.day + 7 * weeks,
  );

  /// Select [day] outright, switching weeks if it lies outside the visible
  /// one — the rest day's "Open <last session>" jump.
  void _jumpToDay(DateTime day) {
    setState(() {
      _weekStart = _mondayOf(day);
      _selectedDay = day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final report = ref.watch(dayReportProvider(_selectedDay));
    final unit = ref.watch(weightUnitProvider);
    final isCurrentWeek = _weekStart == _mondayOf(DateTime.now());

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                (AppSizes.contentPaddingH + 4).w,
                8.h,
                AppSizes.contentPaddingH.w,
                4.h,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.reports,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  LiquidGlassButton(
                    width: AppSizes.headerActionBtn.w,
                    height: AppSizes.headerActionBtn.w,
                    opacity: 0.25,
                    radius: (AppSizes.headerActionBtn / 2).r,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Icon(
                      Icons.check_rounded,
                      color: colors.accent,
                      size: AppSizes.headerActionIcon.sp,
                    ),
                  ),
                ],
              ),
            ),

            // ── Week navigator + day circles ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.contentPaddingH.w,
                8.h,
                AppSizes.contentPaddingH.w,
                0,
              ),
              child: _WeekNavigator(
                weekStart: _weekStart,
                locale: locale,
                onPrevious: () => _selectWeek(_shiftedWeek(-1)),
                onNext: isCurrentWeek
                    ? null
                    : () => _selectWeek(_shiftedWeek(1)),
                onTapRange: _openWeekPicker,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.contentPaddingH.w,
                10.h,
                AppSizes.contentPaddingH.w,
                8.h,
              ),
              child: _DaySelector(
                weekStart: _weekStart,
                selectedDay: _selectedDay,
                locale: locale,
                onSelectDay: (d) => setState(() => _selectedDay = d),
              ),
            ),

            // ── Report body ──
            Expanded(
              child: report.when(
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: colors.accent,
                    strokeWidth: 2.w,
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (r) => !r.hasData
                    ? _EmptyDay(
                        day: _selectedDay,
                        weekStart: _weekStart,
                        l10n: l10n,
                        locale: locale,
                        onOpenDay: _jumpToDay,
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          AppSizes.contentPaddingH.w,
                          12.h,
                          AppSizes.contentPaddingH.w,
                          40.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DaySummaryLine(
                              day: _selectedDay,
                              report: r,
                              l10n: l10n,
                              locale: locale,
                            ),
                            _WeightsSection(report: r, unit: unit, l10n: l10n),
                            SizedBox(height: 36.h),
                            _CalBurnedSection(
                              report: r,
                              l10n: l10n,
                              locale: locale,
                              dailyGoal: _dailyGoal(ref),
                            ),
                            SizedBox(height: 36.h),
                            _DurationSection(report: r, l10n: l10n),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Weekly calorie goal spread across 7 days, if the user set one.
  double? _dailyGoal(WidgetRef ref) {
    final weekly = ref.read(weeklyCalorieGoalProvider);
    return weekly == null || weekly <= 0 ? null : weekly / 7;
  }

  Future<void> _openWeekPicker() async {
    final monday = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _WeekPickerSheet(initialWeekStart: _weekStart),
    );
    if (monday != null) _selectWeek(monday);
  }
}

// ── Week navigator + day circles ─────────────────────────────────────

/// ‹ [📅 date range · This week ⌄] › — the arrows step a week, the pill
/// opens the calendar picker. The right arrow is disabled in the current
/// week.
class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.weekStart,
    required this.locale,
    required this.onPrevious,
    required this.onNext,
    required this.onTapRange,
  });
  final DateTime weekStart;
  final Locale locale;
  final VoidCallback onPrevious;

  /// Null when the week contains today (nothing to step forward to).
  final VoidCallback? onNext;
  final VoidCallback onTapRange;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final chipColor = _chipColor(colors);
    final thisMonday = _mondayOf(DateTime.now());
    final lastMonday = DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day - 7,
    );
    final fmt = DateFormat.MMMd(locale.languageCode);
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    final range = '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}';
    final relative = weekStart == thisMonday
        ? l10n.thisWeek
        : weekStart == lastMonday
        ? l10n.lastWeek
        : null;

    return Row(
      children: [
        _NavCircle(
          icon: Icons.chevron_left_rounded,
          color: chipColor,
          onTap: onPrevious,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: GestureDetector(
            onTap: onTapRange,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 36.h,
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: colors.accent,
                    size: 16.sp,
                  ),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      range,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (relative != null) ...[
                    SizedBox(width: 6.w),
                    Text(
                      '· $relative',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.expand_more_rounded,
                    color: colors.textSecondary,
                    size: 16.sp,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        _NavCircle(
          icon: Icons.chevron_right_rounded,
          color: chipColor,
          onTap: onNext,
        ),
      ],
    );
  }
}

/// 36 px round week-step button; dimmed and inert when [onTap] is null.
class _NavCircle extends StatelessWidget {
  const _NavCircle({
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Icon(icon, color: colors.textPrimary, size: 20.sp),
        ),
      ),
    );
  }
}

/// Mon…Sun: weekday initial over a 40 px date circle, trained-day dot under.
class _DaySelector extends ConsumerWidget {
  const _DaySelector({
    required this.weekStart,
    required this.selectedDay,
    required this.locale,
    required this.onSelectDay,
  });
  final DateTime weekStart;
  final DateTime selectedDay;
  final Locale locale;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final chipColor = _chipColor(colors);
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    final trained =
        ref
            .watch(trainedDaysInRangeProvider((from: weekStart, to: weekEnd)))
            .asData
            ?.value ??
        const <int>{};
    final dayFmt = DateFormat.E(locale.languageCode);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          () {
            final date = DateTime(
              weekStart.year,
              weekStart.month,
              weekStart.day + i,
            );
            final selected = date == selectedDay;
            final isToday = date == today;
            final isFuture = date.isAfter(today);
            final hasSession = trained.contains(date.millisecondsSinceEpoch);
            return GestureDetector(
              onTap: () => onSelectDay(date),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayFmt.format(date).substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: selected
                          ? colors.textPrimary
                          : colors.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40.w,
                    height: 40.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? colors.accent : chipColor,
                      border: isToday && !selected
                          ? Border.all(color: colors.accent, width: 1.5)
                          : null,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: selected
                            ? colors.background
                            : isFuture
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Container(
                    width: 4.w,
                    height: 4.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasSession ? colors.accent : Colors.transparent,
                    ),
                  ),
                ],
              ),
            );
          }(),
      ],
    );
  }
}

/// "Friday, Sep 4 · 5 exercises · 60 min" above a trained day's sections.
class _DaySummaryLine extends StatelessWidget {
  const _DaySummaryLine({
    required this.day,
    required this.report,
    required this.l10n,
    required this.locale,
  });
  final DateTime day;
  final DayReport report;
  final AppLocalizations l10n;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final seconds = report.exercises.fold<int>(
      0,
      (a, e) => a + e.durationSeconds,
    );
    final minutes = (seconds / 60).round();
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Text(
        '${_longDay(day, locale)} · '
        '${l10n.premadeExercisesCount(report.exercises.length)} · '
        '$minutes ${l10n.minUnit}',
        style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
      ),
    );
  }
}

/// Rest-day body: a "no workout" card that points back at the last session,
/// then the week's totals and one calorie bar per trained day.
class _EmptyDay extends ConsumerWidget {
  const _EmptyDay({
    required this.day,
    required this.weekStart,
    required this.l10n,
    required this.locale,
    required this.onOpenDay,
  });
  final DateTime day;
  final DateTime weekStart;
  final AppLocalizations l10n;
  final Locale locale;
  final ValueChanged<DateTime> onOpenDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastTrained =
        ref.watch(lastTrainedDayBeforeProvider(day)).asData?.value;
    final week =
        ref.watch(weekSummaryProvider(weekStart)).asData?.value ??
        const WeekSummary();

    final status = day == today
        ? l10n.today
        : day.isAfter(today)
        ? l10n.reportUpcoming
        : l10n.reportRestDay;
    final shortFmt = DateFormat.MMMEd(locale.languageCode);
    final weekdayFmt = DateFormat.E(locale.languageCode);
    final grouped = NumberFormat.decimalPattern(locale.toString());
    final maxCal = week.days.fold<int>(0, (m, d) => math.max(m, d.calories));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.contentPaddingH.w,
        12.h,
        AppSizes.contentPaddingH.w,
        40.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_longDay(day, locale)} · $status',
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            decoration: BoxDecoration(
              color: colors.cardElevated,
              borderRadius: BorderRadius.circular(25.r),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.bedtime_rounded,
                  color: colors.textSecondary,
                  size: 34.sp,
                ),
                SizedBox(height: 8.h),
                Text(
                  l10n.reportNoData,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (lastTrained != null) ...[
                  SizedBox(height: 8.h),
                  Text(
                    l10n.reportRestCounts(_longDay(lastTrained, locale)),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.sp,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _AccentPill(
                    icon: Icons.history_rounded,
                    label: l10n.reportOpenDay(shortFmt.format(lastTrained)),
                    onTap: () => onOpenDay(lastTrained),
                  ),
                ],
              ],
            ),
          ),
          if (week.sessions > 0) ...[
            SizedBox(height: 24.h),
            _Eyebrow(l10n.reportWeekSoFar),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: '${week.sessions}',
                    label: l10n.reportSessions,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _StatTile(
                    value: grouped.format(week.calories),
                    label: l10n.calBurned,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _StatTile(
                    value: _formatDuration(week.durationSeconds, l10n),
                    label: l10n.duration,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            for (final d in week.days)
              _StatBar(
                label: weekdayFmt.format(d.date),
                fraction: maxCal <= 0 ? 0 : d.calories / maxCal,
                value: grouped.format(d.calories),
                unit: l10n.calUnit,
              ),
          ],
        ],
      ),
    );
  }
}

/// "2h 41" past the hour, "41 Min" under it.
String _formatDuration(int seconds, AppLocalizations l10n) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return h > 0
      ? '${h}h ${m.toString().padLeft(2, '0')}'
      : '$m ${l10n.minUnit}';
}

/// Big number over a small label — the "This week so far" tiles.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 11.sp),
          ),
        ],
      ),
    );
  }
}

/// Accent-tinted pill button (icon + label) — the picker's "This Week" jump
/// and the rest day's "Open <last session>".
class _AccentPill extends StatelessWidget {
  const _AccentPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36.h,
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.14),
          border: Border.all(color: colors.accent.withValues(alpha: 0.30)),
          borderRadius: BorderRadius.circular(100.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.accent, size: 14.sp),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: colors.accent,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Legend swatch: 8 px dot + 11 px label.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.w),
        Text(
          label,
          style: TextStyle(color: colors.textPrimary, fontSize: 11.sp),
        ),
      ],
    );
  }
}

/// Uppercase section eyebrow (12/800, 0.08 em tracking, secondary).
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 12.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.08 * 12.sp,
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 20.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Horizontal stat bar: label, filled track, trailing value — the repeated
/// "Squats ▬▬▬ 50 Kg" rows in the mock. The unit renders smaller than the
/// number, matching the mock's "50 ᴋɢ" treatment.
class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.fraction,
    required this.value,
    required this.unit,
    this.index,
  });

  /// 1-based position matching the chart's x axis; omitted on rows that
  /// have no chart (the rest day's per-day bars).
  final int? index;
  final String label;
  final double fraction;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        children: [
          if (index != null)
            SizedBox(
              width: 16.w,
              child: Text(
                '$index',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          SizedBox(
            width: 84.w,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textPrimary, fontSize: 11.sp),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: Stack(
                children: [
                  Container(
                    height: 8.h,
                    color: colors.accent.withValues(alpha: 0.14),
                  ),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0.03, 1.0),
                    child: Container(
                      height: 8.h,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10.w),
          SizedBox(
            width: 58.w,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 8.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weights section ──────────────────────────────────────────────────

class _WeightsSection extends StatelessWidget {
  const _WeightsSection({
    required this.report,
    required this.unit,
    required this.l10n,
  });
  final DayReport report;
  final WeightUnit unit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maxTop = report.exercises.fold<double>(
      0,
      (m, e) => math.max(m, e.topWeightKg),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title left, series legend right — replaces the labels that used
        // to be painted onto the lines.
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  l10n.weights,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _LegendDot(color: colors.accent, label: l10n.thisWeek),
              SizedBox(width: 14.w),
              _LegendDot(color: colors.textSecondary, label: l10n.lastWeek),
            ],
          ),
        ),
        SizedBox(
          height: 170.h,
          width: double.infinity,
          child: CustomPaint(
            painter: _WeightComparePainter(
              thisWeek: [
                for (final e in report.exercises)
                  convertFromKg(e.topWeightKg, unit),
              ],
              lastWeek: [
                for (final e in report.exercises)
                  convertFromKg(e.lastWeekTopWeightKg, unit),
              ],
              thisColor: colors.accent,
              lastColor: colors.textSecondary,
              gridColor: colors.textSecondary.withValues(alpha: 0.25),
              // Axis numbers read as axis, not data.
              axisTextColor: colors.textSecondary,
              textSize: 10.sp,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        for (var i = 0; i < report.exercises.length; i++)
          _StatBar(
            index: i + 1,
            label: report.exercises[i].name,
            fraction: maxTop <= 0 ? 0 : report.exercises[i].topWeightKg / maxTop,
            value: formatWeight(
              report.exercises[i].topWeightKg,
              unit,
              decimals: 0,
            ),
            unit: weightUnitLabel(unit),
          ),
      ],
    );
  }
}

// ── Cal Burned section ───────────────────────────────────────────────

class _CalBurnedSection extends StatelessWidget {
  const _CalBurnedSection({
    required this.report,
    required this.l10n,
    required this.locale,
    required this.dailyGoal,
  });
  final DayReport report;
  final AppLocalizations l10n;
  final Locale locale;
  final double? dailyGoal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maxCal = report.exercises.fold<int>(
      0,
      (m, e) => math.max(m, e.calories),
    );
    final total = report.totalCalories;

    // Outer ring fills toward the daily goal if set; else improvement over
    // the same day last week; else full when there's any burn. The inner gray
    // ring shows the same day last week against the same reference.
    final reference =
        dailyGoal ??
        (report.lastWeekTotalCalories > 0
            ? report.lastWeekTotalCalories.toDouble()
            : total.toDouble());
    final fraction = reference <= 0 ? 0.0 : (total / reference).clamp(0.0, 1.0);
    final lastFraction = reference <= 0
        ? 0.0
        : (report.lastWeekTotalCalories / reference).clamp(0.0, 1.0);
    final compact = NumberFormat.compact(locale: locale.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.calBurned),
        Center(
          child: SizedBox(
            width: 180.w,
            height: 180.w,
            child: CustomPaint(
              painter: _RingPainter(
                fraction: fraction,
                lastFraction: lastFraction,
                color: colors.accent,
                lastColor: colors.textSecondary,
                trackColor: colors.textSecondary.withValues(alpha: 0.18),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      compact.format(total),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.calBurned,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 20.h),
        for (var i = 0; i < report.exercises.length; i++)
          _StatBar(
            index: i + 1,
            label: report.exercises[i].name,
            fraction: maxCal <= 0 ? 0 : report.exercises[i].calories / maxCal,
            value: '${report.exercises[i].calories}',
            unit: l10n.calUnit,
          ),
      ],
    );
  }
}

// ── Total Duration section ───────────────────────────────────────────

class _DurationSection extends StatelessWidget {
  const _DurationSection({required this.report, required this.l10n});
  final DayReport report;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final maxDur = report.exercises.fold<int>(
      0,
      (m, e) => math.max(m, e.durationSeconds),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.totalDuration),
        SizedBox(
          height: 150.h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < report.exercises.length; i++)
                Expanded(
                  child: _VerticalBar(
                    fraction: maxDur <= 0
                        ? 0
                        : report.exercises[i].durationSeconds / maxDur,
                    label: '${l10n.exercisePrefix} ${i + 1}',
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        for (var i = 0; i < report.exercises.length; i++)
          _StatBar(
            index: i + 1,
            label: report.exercises[i].name,
            fraction: maxDur <= 0
                ? 0
                : report.exercises[i].durationSeconds / maxDur,
            value: '${(report.exercises[i].durationSeconds / 60).round()}',
            unit: l10n.minUnit,
          ),
      ],
    );
  }
}

/// Thick rounded bar over a faint full-height track — the pill-style duration
/// bars in the mock.
class _VerticalBar extends StatelessWidget {
  const _VerticalBar({required this.fraction, required this.label});
  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(100.r);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: 14.w,
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.10),
                  borderRadius: radius,
                ),
              ),
              FractionallySizedBox(
                heightFactor: fraction.clamp(0.06, 1.0),
                child: Container(
                  width: 14.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.accent,
                        colors.accent.withValues(alpha: 0.55),
                      ],
                    ),
                    borderRadius: radius,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────

/// This-week vs last-week per-exercise weight. x = exercise index (1..n),
/// last week drawn as a soft filled line, this week as a bright line. The
/// series legend lives in the section header, not on the chart.
class _WeightComparePainter extends CustomPainter {
  _WeightComparePainter({
    required this.thisWeek,
    required this.lastWeek,
    required this.thisColor,
    required this.lastColor,
    required this.gridColor,
    required this.axisTextColor,
    required this.textSize,
  });
  final List<double> thisWeek;
  final List<double> lastWeek;
  final Color thisColor;
  final Color lastColor;
  final Color gridColor;
  final Color axisTextColor;
  final double textSize;

  TextPainter _tp(String s, Color c, {FontWeight? w}) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(color: c, fontSize: textSize, fontWeight: w),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final n = thisWeek.length;
    final peakVal = [...thisWeek, ...lastWeek].fold<double>(0, math.max);
    // Round the axis top to a clean number.
    final step = peakVal <= 50 ? 25.0 : (peakVal <= 200 ? 50.0 : 100.0);
    final axisMax = math.max(step, (peakVal / step).ceilToDouble() * step);

    final leftGutter =
        _tp(groupDigits('${axisMax.round()}'), axisTextColor).width + 8;
    final bottomGutter = textSize + 10;
    // Half a label of headroom so the top axis number isn't clipped, and a
    // right inset so the last x label isn't either.
    final topPad = textSize / 2 + 4;
    final chart = Rect.fromLTRB(
      leftGutter,
      topPad,
      size.width - 12,
      size.height - bottomGutter,
    );

    // Dashed gridlines + axis numbers.
    final grid = Paint()
      ..strokeWidth = 1
      ..color = gridColor;
    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - chart.height * i / 4;
      for (var x = chart.left; x < chart.right; x += 10) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 5, chart.right), y),
          grid,
        );
      }
      final tp =
          _tp(groupDigits('${(axisMax * i / 4).round()}'), axisTextColor);
      tp.paint(canvas, Offset(chart.left - tp.width - 6, y - tp.height / 2));
    }

    if (n == 0) return;
    double xAt(int i) =>
        n == 1 ? chart.center.dx : chart.left + chart.width * i / (n - 1);
    double yOf(double v) => chart.bottom - chart.height * v / axisMax;

    Path lineOf(List<double> vals) {
      final p = Path()..moveTo(xAt(0), yOf(vals[0]));
      for (var i = 1; i < n; i++) {
        p.lineTo(xAt(i), yOf(vals[i]));
      }
      return p;
    }

    Path areaOf(Path line) => Path.from(line)
      ..lineTo(xAt(n - 1), chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();

    // Last week: soft filled area + line.
    final lastPath = lineOf(lastWeek);
    // This week: accent gradient area + bright line on top.
    final thisPath = lineOf(thisWeek);
    canvas
      ..drawPath(
        areaOf(lastPath),
        Paint()..color = lastColor.withValues(alpha: 0.18),
      )
      ..drawPath(
        lastPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = lastColor,
      )
      ..drawPath(
        areaOf(thisPath),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              thisColor.withValues(alpha: 0.28),
              thisColor.withValues(alpha: 0),
            ],
          ).createShader(chart),
      )
      ..drawPath(
        thisPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = thisColor,
      );

    // x labels: bare 1…n, matching the numbered stat bars below.
    for (var i = 0; i < n; i++) {
      final tp = _tp('${i + 1}', axisTextColor, w: FontWeight.w700);
      final x = (xAt(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(x, chart.bottom + 8));
    }
  }

  @override
  bool shouldRepaint(_WeightComparePainter old) =>
      old.thisWeek != thisWeek || old.lastWeek != lastWeek;
}

/// Double progress ring with rounded caps — thick accent outer ring for the
/// selected day, thinner gray inner ring for the same day last week.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.lastFraction,
    required this.color,
    required this.lastColor,
    required this.trackColor,
  });
  final double fraction;
  final double lastFraction;
  final Color color;
  final Color lastColor;
  final Color trackColor;

  void _ring(
    Canvas canvas,
    Offset center,
    double radius,
    double width,
    double frac,
    Color arcColor,
  ) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, stroke..color = trackColor);
    if (frac <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * frac,
      false,
      stroke..color = arcColor,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const outerWidth = 15.0;
    const innerWidth = 9.0;
    final outerRadius = size.width / 2 - outerWidth / 2 - 1;
    final innerRadius = outerRadius - outerWidth / 2 - innerWidth / 2 - 5;
    _ring(canvas, center, outerRadius, outerWidth, fraction, color);
    _ring(canvas, center, innerRadius, innerWidth, lastFraction, lastColor);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.lastFraction != lastFraction;
}

// ── Week picker calendar ─────────────────────────────────────────────

class _WeekPickerSheet extends ConsumerStatefulWidget {
  const _WeekPickerSheet({required this.initialWeekStart});
  final DateTime initialWeekStart;

  @override
  ConsumerState<_WeekPickerSheet> createState() => _WeekPickerSheetState();
}

class _WeekPickerSheetState extends ConsumerState<_WeekPickerSheet> {
  late DateTime _month; // first day of the visible month
  int _dir = 1; // last month-shift direction, drives the slide animation

  @override
  void initState() {
    super.initState();
    _month = DateTime(
      widget.initialWeekStart.year,
      widget.initialWeekStart.month,
    );
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _dir = delta.sign;
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  void _jumpToMonth(DateTime target) {
    if (target.year == _month.year && target.month == _month.month) return;
    HapticFeedback.selectionClick();
    setState(() {
      _dir = target.isBefore(_month) ? -1 : 1;
      _month = target;
    });
  }

  void _pickWeek(DateTime monday) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(monday);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    // 6-week grid starting on the Monday on/before the 1st.
    final gridStart = _mondayOf(_month);
    final gridEnd = gridStart.add(const Duration(days: 42));
    final trained =
        ref
            .watch(trainedDaysInRangeProvider((from: gridStart, to: gridEnd)))
            .asData
            ?.value ??
        const <int>{};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedWeek = widget.initialWeekStart;

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 12.h),
      child: SafeArea(
        top: false,
        // Frosted glass sheet (house style for sheets/panels).
        child: GlassSurface(
          radius: 32.r,
          tint: colors.panelBackground.withValues(alpha: 0.78),
          shadow: GlassDecoration.cardShadow(),
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 18.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Month navigation: bold month + dim year; tapping the title
              // jumps back to the current month.
              Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        _jumpToMonth(DateTime(today.year, today.month)),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text.rich(
                        key: ValueKey(_month),
                        TextSpan(
                          children: [
                            TextSpan(
                              text: DateFormat.MMMM(
                                locale.languageCode,
                              ).format(_month),
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '  ${DateFormat.y(locale.languageCode).format(_month)}',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  LiquidGlassButton(
                    width: 34.w,
                    height: 34.w,
                    radius: 17.r,
                    onTap: () => _shiftMonth(-1),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: colors.textPrimary,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  LiquidGlassButton(
                    width: 34.w,
                    height: 34.w,
                    radius: 17.r,
                    onTap: () => _shiftMonth(1),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textPrimary,
                      size: 20.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              // Weekday header (Mon-anchored).
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Text(
                        DateFormat.E(locale.languageCode)
                            .format(gridStart.add(Duration(days: i)))
                            .substring(0, 1)
                            .toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary.withValues(alpha: 0.8),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6.h),
              // Swipe left/right anywhere on the grid to change months;
              // month swaps slide in from the direction of travel.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v.abs() < 100) return;
                  _shiftMonth(v < 0 ? 1 : -1);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0.08 * _dir, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_month),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var w = 0; w < 6; w++)
                        () {
                          // Calendar arithmetic (not Duration) so a DST
                          // shift can't move the row off midnight — the
                          // picked Monday is compared for equality.
                          final rowMonday = DateTime(
                            gridStart.year,
                            gridStart.month,
                            gridStart.day + w * 7,
                          );
                          final isSelected = rowMonday == selectedWeek;
                          return GestureDetector(
                            onTap: () => _pickWeek(rowMonday),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: 2.h),
                              decoration: isSelected
                                  ? BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          colors.accent.withValues(
                                            alpha: 0.20,
                                          ),
                                          colors.accent.withValues(
                                            alpha: 0.06,
                                          ),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: colors.accent.withValues(
                                          alpha: 0.38,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        100.r,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.accent.withValues(
                                            alpha: 0.15,
                                          ),
                                          blurRadius: 14.w,
                                        ),
                                      ],
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  for (var i = 0; i < 7; i++)
                                    () {
                                      final cellDate = DateTime(
                                        rowMonday.year,
                                        rowMonday.month,
                                        rowMonday.day + i,
                                      );
                                      return Expanded(
                                        child: _DayCell(
                                          date: cellDate,
                                          month: _month.month,
                                          today: today,
                                          trained: trained.contains(
                                            cellDate.millisecondsSinceEpoch,
                                          ),
                                          colors: colors,
                                        ),
                                      );
                                    }(),
                                ],
                              ),
                            ),
                          );
                        }(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // Quick jump: select the current week.
              _AccentPill(
                icon: Icons.today_rounded,
                label: l10n.thisWeek,
                onTap: () => _pickWeek(_mondayOf(today)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.month,
    required this.today,
    required this.trained,
    required this.colors,
  });
  final DateTime date;
  final int month;
  final DateTime today;
  final bool trained;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context) {
    final inMonth = date.month == month;
    final isToday = date == today;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Today gets a filled accent circle; other days plain numbers.
          Container(
            width: 26.w,
            height: 26.w,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent,
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.35),
                        blurRadius: 10.w,
                      ),
                    ],
                  )
                : null,
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: isToday
                    ? colors.background
                    : inMonth
                    ? colors.textPrimary
                    : colors.textSecondary.withValues(alpha: 0.35),
                fontSize: 12.sp,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: 3.h),
          // Trained-day dot (dimmed outside the visible month).
          Container(
            width: 4.5.w,
            height: 4.5.w,
            decoration: BoxDecoration(
              color: trained
                  ? colors.accent.withValues(alpha: inMonth ? 1.0 : 0.4)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
