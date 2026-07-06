import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/settings/app_settings_provider.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Full-screen "Reports" view opened from the Weekly Reports card in the
/// Status sheet. A week of day circles + a week pill drive a per-day report:
/// weights (this vs last week), calories burned, and duration — all broken
/// down per exercise for the selected day.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final report = ref.watch(dayReportProvider(_selectedDay));
    final unit = ref.watch(weightUnitProvider);

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
                    width: 44.w,
                    height: 44.h,
                    opacity: 0.25,
                    radius: 22.r,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Icon(
                      Icons.check_rounded,
                      color: colors.accent,
                      size: 20.sp,
                    ),
                  ),
                ],
              ),
            ),

            // ── Day circles + Week pill ──
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.contentPaddingH.w,
                vertical: 8.h,
              ),
              child: _DaySelector(
                weekStart: _weekStart,
                selectedDay: _selectedDay,
                locale: locale,
                onSelectDay: (d) => setState(() => _selectedDay = d),
                onTapWeek: _openWeekPicker,
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
                    ? _EmptyDay(l10n: l10n)
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

// ── Day circles + week pill ──────────────────────────────────────────

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.weekStart,
    required this.selectedDay,
    required this.locale,
    required this.onSelectDay,
    required this.onTapWeek,
  });
  final DateTime weekStart;
  final DateTime selectedDay;
  final Locale locale;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onTapWeek;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Unselected chips carry a faint accent wash (the olive look in the mock).
    final chipColor = Color.alphaBlend(
      colors.accent.withValues(alpha: 0.13),
      colors.cardElevated,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          () {
            final date = weekStart.add(Duration(days: i));
            final initial = DateFormat.E(
              locale.languageCode,
            ).format(date).substring(0, 1);
            final selected = date == selectedDay;
            final isFuture = date.isAfter(today);
            return GestureDetector(
              onTap: () => onSelectDay(date),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32.w,
                height: 32.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors.accent : chipColor,
                  border: date == today && !selected
                      ? Border.all(color: colors.accent, width: 1.5)
                      : null,
                ),
                child: Text(
                  initial.toUpperCase(),
                  style: TextStyle(
                    color: selected
                        ? colors.background
                        : isFuture
                        ? colors.textSecondary
                        : colors.textPrimary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }(),
        // Week pill → opens the calendar.
        GestureDetector(
          onTap: onTapWeek,
          child: Container(
            height: 32.w,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(16.w),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).week,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 2.w),
                Icon(
                  Icons.expand_more_rounded,
                  color: colors.textSecondary,
                  size: 15.sp,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Text(
        l10n.reportNoData,
        style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
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
  });
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
          SizedBox(
            width: 62.w,
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
        _SectionHeader(l10n.weights),
        SizedBox(
          height: 180.h,
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
              thisLabel: l10n.thisWeek,
              lastLabel: l10n.lastWeek,
              thisColor: colors.accent,
              lastColor: colors.textSecondary,
              gridColor: colors.textSecondary.withValues(alpha: 0.25),
              axisTextColor: colors.textPrimary,
              textSize: 10.sp,
              xLabelPrefix: l10n.exercisePrefix,
            ),
          ),
        ),
        SizedBox(height: 16.h),
        for (final e in report.exercises)
          _StatBar(
            label: e.name,
            fraction: maxTop <= 0 ? 0 : e.topWeightKg / maxTop,
            value: formatWeight(e.topWeightKg, unit, decimals: 0),
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
        for (final e in report.exercises)
          _StatBar(
            label: e.name,
            fraction: maxCal <= 0 ? 0 : e.calories / maxCal,
            value: '${e.calories}',
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
        for (final e in report.exercises)
          _StatBar(
            label: e.name,
            fraction: maxDur <= 0 ? 0 : e.durationSeconds / maxDur,
            value: '${(e.durationSeconds / 60).round()}',
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
/// last week drawn as a soft filled line, this week as a bright line.
class _WeightComparePainter extends CustomPainter {
  _WeightComparePainter({
    required this.thisWeek,
    required this.lastWeek,
    required this.thisLabel,
    required this.lastLabel,
    required this.thisColor,
    required this.lastColor,
    required this.gridColor,
    required this.axisTextColor,
    required this.textSize,
    required this.xLabelPrefix,
  });
  final List<double> thisWeek;
  final List<double> lastWeek;
  final String thisLabel;
  final String lastLabel;
  final Color thisColor;
  final Color lastColor;
  final Color gridColor;
  final Color axisTextColor;
  final double textSize;
  final String xLabelPrefix;

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

    final leftGutter = _tp('${axisMax.round()}', axisTextColor).width + 8;
    final bottomGutter = textSize + 10;
    final topPad = textSize + 8;
    final chart = Rect.fromLTRB(
      leftGutter,
      topPad,
      size.width,
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
      final tp = _tp('${(axisMax * i / 4).round()}', axisTextColor);
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
              thisColor.withValues(alpha: 0.0),
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

    // Series labels above each line's peak.
    void peakLabel(String label, Color color, List<double> vals) {
      var peak = 0;
      for (var i = 1; i < n; i++) {
        if (vals[i] > vals[peak]) peak = i;
      }
      final tp = _tp(label, color, w: FontWeight.w700);
      final x = (xAt(peak) - tp.width / 2).clamp(
        chart.left,
        chart.right - tp.width,
      );
      tp.paint(canvas, Offset(x, yOf(vals[peak]) - tp.height - 5));
    }

    if (lastWeek.any((v) => v > 0)) peakLabel(lastLabel, lastColor, lastWeek);
    peakLabel(thisLabel, thisColor, thisWeek);

    // x labels: "Exe 1", "Exe 2", … (bare index when crowded).
    for (var i = 0; i < n; i++) {
      final label = n <= 8 ? '$xLabelPrefix ${i + 1}' : '${i + 1}';
      final tp = _tp(label, axisTextColor);
      final x = (xAt(i) - tp.width / 2).clamp(
        chart.left - leftGutter,
        size.width - tp.width,
      );
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

  @override
  void initState() {
    super.initState();
    _month = DateTime(
      widget.initialWeekStart.year,
      widget.initialWeekStart.month,
    );
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
          radius: 28.r,
          tint: colors.panelBackground.withValues(alpha: 0.78),
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
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
              SizedBox(height: 14.h),
              // Month navigation. Tapping the title jumps back to the
              // current month.
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(
                      () => _month = DateTime(today.year, today.month),
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      DateFormat.yMMMM(locale.languageCode).format(_month),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _NavArrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _shiftMonth(-1),
                  ),
                  SizedBox(width: 6.w),
                  _NavArrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _shiftMonth(1),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              // Swipe left/right anywhere on the grid to change months.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v.abs() < 100) return;
                  _shiftMonth(v < 0 ? 1 : -1);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                color: colors.textSecondary,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    // Week rows.
                    for (var w = 0; w < 6; w++)
                      () {
                        final rowMonday = gridStart.add(Duration(days: w * 7));
                        final isSelected = rowMonday == selectedWeek;
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pop(rowMonday),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 2.h),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.accent.withValues(alpha: 0.14)
                                  : null,
                              border: isSelected
                                  ? Border.all(
                                      color: colors.accent.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 1,
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(100.r),
                            ),
                            child: Row(
                              children: [
                                for (var i = 0; i < 7; i++)
                                  Expanded(
                                    child: _DayCell(
                                      date: rowMonday.add(Duration(days: i)),
                                      month: _month.month,
                                      today: today,
                                      trained: trained.contains(
                                        rowMonday
                                            .add(Duration(days: i))
                                            .millisecondsSinceEpoch,
                                      ),
                                      colors: colors,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.w,
        height: 32.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.cardElevated,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: colors.textPrimary, size: 20.sp),
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
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.accent, width: 1.5),
                  )
                : null,
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: isToday
                    ? colors.accent
                    : inMonth
                    ? colors.textPrimary
                    : colors.textSecondary.withValues(alpha: 0.4),
                fontSize: 12.sp,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          // Trained-day dot.
          Container(
            width: 4.w,
            height: 4.w,
            decoration: BoxDecoration(
              color: trained ? colors.accent : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
