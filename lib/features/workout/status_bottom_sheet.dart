import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/settings/app_settings_provider.dart';
import 'package:my_gym_bro/features/workout/reports_screen.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Show the Status bottom sheet — analytics feed: weekly calories,
/// muscle-balance radar, lifetime tonnage, reps-vs-weight and calorie rings.
void showStatusBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _StatusSheet(),
  );
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet();

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  static const _initialSize = 0.85;

  /// 0 = resting sheet (cards on a panel), 1 = expanded to full screen
  /// (pure background, no cards) — driven by the sheet's drag extent.
  double _t = 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    // viewPadding, not padding: showModalBottomSheet removes the top
    // padding from its subtree, but the raw status-bar inset is still
    // needed once the sheet covers the whole screen.
    final topPad = MediaQuery.viewPaddingOf(context).top;

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        final t = ((n.extent - _initialSize) / (1.0 - _initialSize)).clamp(
          0.0,
          1.0,
        );
        if ((t - _t).abs() > 0.001) setState(() => _t = t);
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: _initialSize,
        minChildSize: 0.5,
        // maxChildSize defaults to 1.0 — full screen, per the mock.
        // Clip so scrolled content can't bleed past the rounded top corners.
        builder: (context, scrollController) => Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Color.lerp(colors.panelBackground, colors.background, _t),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet.r * (1 - _t)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar — fades out as the sheet reaches full screen,
              // making room for the status bar.
              SizedBox(height: 12.h + topPad * _t),
              Opacity(
                opacity: 1 - _t,
                child: Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // ── Pinned header: "Status" ... check ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 4.w),
                      child: Text(
                        l10n.status,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.25,
                      radius: 24.r,
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.check_rounded,
                        color: colors.accent,
                        size: 22.sp,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable analytics feed. Weekly + radar sit in cards at
              // rest; the cards dissolve into the background as the sheet
              // expands to full screen (mock behaviour). ──
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(top: 20.h, bottom: 40.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.contentPaddingH.w,
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ReportsScreen(),
                                ),
                              ),
                          child: _FadeCard(
                            t: _t,
                            child: _WeeklyReportSection(l10n: l10n),
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.contentPaddingH.w,
                        ),
                        child: _FadeCard(
                          t: _t,
                          child: _MuscleRadarSection(l10n: l10n),
                        ),
                      ),
                      // Each section brings its own top spacing so a hidden
                      // one leaves no gap.
                      _TonnageSection(l10n: l10n),
                      _RepsWeightSection(l10n: l10n),
                      _RingsSection(l10n: l10n),
                    ],
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

/// Rounded card that dissolves into the sheet background as the sheet
/// expands ([t] 0 → 1). Padding stays constant so content doesn't jump.
class _FadeCard extends StatelessWidget {
  const _FadeCard({required this.t, required this.child});
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 20.h),
      decoration: BoxDecoration(
        color: colors.cardElevated.withValues(alpha: 1 - t),
        borderRadius: BorderRadius.circular(25.r),
      ),
      child: child,
    );
  }
}

/// Caption line with highlighted value substrings, e.g. the "3,500 kg" in
/// "You've lifted 3,500 kg since day one!".
class _Caption extends StatelessWidget {
  const _Caption({required this.text, required this.highlights});
  final String text;
  final Map<String, Color> highlights;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final base = TextStyle(
      color: colors.textPrimary,
      fontSize: 17.sp,
      fontWeight: FontWeight.w700,
      height: 1.35,
    );

    final spans = <TextSpan>[];
    var rest = text;
    while (rest.isNotEmpty) {
      String? bestKey;
      var bestIdx = -1;
      for (final k in highlights.keys) {
        final i = rest.indexOf(k);
        if (i >= 0 && (bestIdx < 0 || i < bestIdx)) {
          bestIdx = i;
          bestKey = k;
        }
      }
      if (bestKey == null) {
        spans.add(TextSpan(text: rest));
        break;
      }
      if (bestIdx > 0) spans.add(TextSpan(text: rest.substring(0, bestIdx)));
      spans.add(
        TextSpan(
          text: bestKey,
          style: TextStyle(color: highlights[bestKey]),
        ),
      );
      rest = rest.substring(bestIdx + bestKey.length);
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      textAlign: TextAlign.center,
    );
  }
}

// ── Weekly Reports — daily calorie bars vs goal ──────────────────────

class _WeeklyReportSection extends ConsumerWidget {
  const _WeeklyReportSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final locale = Localizations.localeOf(context);
    final daily = ref.watch(dailyCaloriesThisWeekProvider);
    final strip = ref.watch(weekStripProvider(locale));
    final goal = ref.watch(weeklyCalorieGoalProvider);

    final days = daily.asData?.value ?? const [0, 0, 0, 0, 0, 0, 0];
    final burned = days.fold<int>(0, (a, b) => a + b);
    final kcalText = goal != null && goal > 0
        ? l10n.statusKcalProgress(burned, goal.round())
        : l10n.statusKcalNoGoal(burned);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Row(
        children: [
          // Left: label + kcal progress
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.weeklyReports,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.textPrimary,
                      size: 14.sp,
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  kcalText,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // Right: Mon..Sun bars
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 140.h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const Spacer(),
                    _DayBar(
                      value: days[i],
                      max: days.reduce(math.max),
                      label: strip.asData?.value[i].abbreviation ?? '',
                      isToday: strip.asData?.value[i].isToday ?? false,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.value,
    required this.max,
    required this.label,
    required this.isToday,
  });
  final int value;
  final int max;
  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trackHeight = 100.0.h;
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final fillHeight = value <= 0
        ? 4.0.h
        : math.max(6.0.h, trackHeight * fraction);

    final bar = SizedBox(
      width: 6.w,
      height: trackHeight,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
          Container(
            height: fillHeight,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Every bar gets the pill wrapper (only today's is visible) so all
        // columns share the same height and stay aligned.
        Container(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 6.h),
          decoration: BoxDecoration(
            border: Border.all(
              color: isToday
                  ? colors.textSecondary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: bar,
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            color: isToday ? colors.textPrimary : colors.textSecondary,
            fontSize: 9.sp,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Muscle balance radar — weekly sets vs target per region ──────────

/// Radar axes clockwise from the top: localized label key, the canonical
/// muscle groups rolled into the axis, and its weekly weighted-set target.
// ponytail: fixed weekly set targets (hypertrophy ~10-20 sets/muscle scaled
// by group size); make user/program-configurable if requested.
const _radarAxes = [
  (
    ['Shoulders', 'Front Delt', 'Side Delt', 'Rear Delt', 'Traps', 'Neck'],
    12.0,
  ),
  (['Quads', 'Hamstrings', 'Glutes', 'Calves'], 20.0),
  (['Chest'], 12.0),
  (['Lats', 'Upper Back', 'Lower Back'], 16.0),
  (['Core'], 8.0),
  (['Biceps', 'Triceps', 'Forearms'], 14.0),
];

class _MuscleRadarSection extends ConsumerWidget {
  const _MuscleRadarSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final doses =
        ref.watch(weeklySetsPerMuscleProvider).asData?.value ??
        const <String, double>{};

    final labels = [
      l10n.shoulders,
      l10n.legs,
      l10n.chest,
      l10n.back,
      l10n.core,
      l10n.arms,
    ];
    final achieved = [
      for (final (groups, target) in _radarAxes)
        (groups.fold<double>(0, (sum, g) => sum + (doses[g] ?? 0)) / target)
            .clamp(0.0, 1.15),
    ];

    return Column(
      children: [
        SizedBox(
          height: 290.h,
          width: double.infinity,
          child: CustomPaint(
            painter: _RadarPainter(
              labels: labels,
              achieved: achieved,
              gridColor: colors.textSecondary.withValues(alpha: 0.25),
              labelColor: colors.textPrimary,
              targetColor: colors.accent,
              achievedColor: colors.trendPositive,
              labelSize: 11.sp,
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: colors.accent, label: l10n.target),
            SizedBox(width: 18.w),
            _LegendDot(color: colors.trendPositive, label: l10n.achieved),
          ],
        ),
      ],
    );
  }
}

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

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.labels,
    required this.achieved,
    required this.gridColor,
    required this.labelColor,
    required this.targetColor,
    required this.achievedColor,
    required this.labelSize,
  });

  final List<String> labels;
  final List<double> achieved; // 0..1.15, 1.0 = target
  final Color gridColor;
  final Color labelColor;
  final Color targetColor;
  final Color achievedColor;
  final double labelSize;

  static const _maxFraction = 1.15;

  Offset _point(Offset center, double radius, int axis, int count) {
    final angle = -math.pi / 2 + 2 * math.pi * axis / count;
    return center + Offset(math.cos(angle), math.sin(angle)) * radius;
  }

  Path _polygon(Offset center, double radius, List<double> fractions) {
    final path = Path();
    for (var i = 0; i < fractions.length; i++) {
      final p = _point(
        center,
        radius * fractions[i] / _maxFraction,
        i,
        fractions.length,
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    final center = Offset(size.width / 2, size.height / 2);
    // Leave room for the labels around the chart.
    final radius = math.min(size.width, size.height) / 2 - 28;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = gridColor;

    // Concentric grid rings + spokes.
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawPath(
        _polygon(center, radius, List.filled(n, _maxFraction * ring / 4)),
        grid,
      );
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, _point(center, radius, i, n), grid);
    }

    // Target — regular polygon at 1.0 (each axis is normalized to its own
    // weekly target).
    final targetPath = _polygon(center, radius, List.filled(n, 1));
    final achievedPath = _polygon(center, radius, achieved);
    canvas
      ..drawPath(
        targetPath,
        Paint()..color = targetColor.withValues(alpha: 0.12),
      )
      ..drawPath(
        targetPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = targetColor,
      )
      // Achieved.
      ..drawPath(
        achievedPath,
        Paint()..color = achievedColor.withValues(alpha: 0.25),
      )
      ..drawPath(
        achievedPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = achievedColor,
      );

    // Axis labels just outside the outer ring.
    for (var i = 0; i < n; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(color: labelColor, fontSize: labelSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final anchor = _point(center, radius + 14, i, n);
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      final dx = anchor.dx - tp.width / 2 + math.cos(angle) * tp.width / 2;
      final dy = anchor.dy - tp.height / 2 + math.sin(angle) * tp.height / 2;
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.achieved != achieved || old.labels != labels;
}

// ── Lifetime tonnage — full-bleed cumulative area chart ──────────────

class _TonnageSection extends ConsumerWidget {
  const _TonnageSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final unit = ref.watch(weightUnitProvider);
    final data = ref.watch(lifetimeChartDataProvider).asData?.value;
    if (data == null || data.cumulativeVolume.length < 2) {
      return const SizedBox.shrink();
    }

    // Grouped like the mock's "3,500 kg" — formatWeight has no grouping.
    final locale = Localizations.localeOf(context).toString();
    final grouped = NumberFormat.decimalPattern(
      locale,
    ).format(convertFromKg(data.totalVolume, unit).round());
    final amount = '$grouped ${weightUnitLabel(unit)}';

    return Column(
      children: [
        SizedBox(height: 28.h),
        // Edge-to-edge, like the mock.
        SizedBox(
          height: 160.h,
          width: double.infinity,
          child: CustomPaint(
            painter: _AreaChartPainter(
              points: data.cumulativeVolume,
              color: colors.accent,
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (AppSizes.contentPaddingH + 12).w,
          ),
          child: _Caption(
            text: l10n.statusLiftedTotal(amount),
            highlights: {amount: colors.trendPositive},
          ),
        ),
      ],
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({required this.points, required this.color});
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = points.last <= 0 ? 1.0 : points.last;
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      // Keep a small top margin so the glow isn't clipped.
      final y = size.height * (1 - 0.92 * points[i] / maxV);
      i == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      )
      // Soft glow under the crisp line.
      ..drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) => old.points != points;
}

// ── Reps vs Weight — monthly dual line chart ─────────────────────────

class _RepsWeightSection extends ConsumerWidget {
  const _RepsWeightSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final locale = Localizations.localeOf(context);
    final data = ref.watch(lifetimeChartDataProvider).asData?.value;
    final monthly = data?.monthly ?? const <MonthlyTraining>[];
    if (monthly.length < 2) return const SizedBox.shrink();

    final monthFmt = DateFormat.MMM(locale.languageCode);
    final pct = data!.volumeIncreasePct;
    final repsLabel = NumberFormat.decimalPattern(
      locale.toString(),
    ).format(data.totalReps);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.contentPaddingH.w),
      child: Column(
        children: [
          SizedBox(height: 56.h),
          SizedBox(
            height: 200.h,
            width: double.infinity,
            child: CustomPaint(
              painter: _DualLinePainter(
                a: [for (final m in monthly) m.reps.toDouble()],
                b: [for (final m in monthly) m.volume],
                labelA: l10n.reps,
                labelB: l10n.weight,
                months: [for (final m in monthly) monthFmt.format(m.month)],
                colorA: colors.accent,
                colorB: colors.trendPositive,
                gridColor: colors.textSecondary.withValues(alpha: 0.25),
                axisTextColor: colors.textPrimary,
                monthTextColor: colors.textSecondary,
                textSize: 10.sp,
              ),
            ),
          ),
          // Always end with a stat line under the chart, like the mock:
          // growth when there is any, otherwise the all-time rep count.
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: pct != null && pct > 0
                ? _Caption(
                    text: l10n.statusVolumeIncrease(pct),
                    highlights: {'$pct%': colors.accent},
                  )
                : _Caption(
                    text: l10n.statusRepsTotal(repsLabel),
                    highlights: {repsLabel: colors.accent},
                  ),
          ),
        ],
      ),
    );
  }
}

/// Mock-style dual line chart: y-axis numbers on the left (scaled to the
/// reps series), dashed gridlines, gradient fill under the reps line, each
/// series labeled above its own peak, month labels under the points. The
/// weight series is normalized to its own max so both lines stay readable.
class _DualLinePainter extends CustomPainter {
  _DualLinePainter({
    required this.a,
    required this.b,
    required this.labelA,
    required this.labelB,
    required this.months,
    required this.colorA,
    required this.colorB,
    required this.gridColor,
    required this.axisTextColor,
    required this.monthTextColor,
    required this.textSize,
  });

  final List<double> a; // reps — owns the y-axis
  final List<double> b; // volume — own scale
  final String labelA;
  final String labelB;
  final List<String> months;
  final Color colorA;
  final Color colorB;
  final Color gridColor;
  final Color axisTextColor;
  final Color monthTextColor;
  final double textSize;

  TextPainter _text(String s, Color color, {FontWeight? weight}) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        color: color,
        fontSize: textSize,
        fontWeight: weight ?? FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final maxA = a.fold<double>(0, math.max);
    // Nice rounded axis top: next multiple of 100 (of 4 for tiny data) so
    // the labels read 0/100/200/... like the mock.
    final axisMax = math.max(4, (maxA / 100).ceilToDouble() * 100).toDouble();

    // Reserve gutters: left for axis numbers, bottom for months, top for
    // the series labels.
    final leftGutter = _text('${axisMax.round()}', axisTextColor).width + 10;
    final bottomGutter = textSize + 10;
    final topPad = textSize + 10;
    final chart = Rect.fromLTRB(
      leftGutter,
      topPad,
      size.width,
      size.height - bottomGutter,
    );

    // Dashed gridlines + axis numbers at 4 divisions.
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
      final tp = _text('${(axisMax * i / 4).round()}', axisTextColor);
      tp.paint(canvas, Offset(chart.left - tp.width - 8, y - tp.height / 2));
    }

    double xAt(int i) => chart.left + chart.width * i / (a.length - 1);
    final maxB = b.fold<double>(0, math.max);
    double yA(int i) => chart.bottom - chart.height * a[i] / axisMax;
    double yB(int i) =>
        chart.bottom - (maxB <= 0 ? 0 : chart.height * 0.9 * b[i] / maxB);

    Path pathOf(double Function(int) yOf) {
      final p = Path()..moveTo(xAt(0), yOf(0));
      for (var i = 1; i < a.length; i++) {
        p.lineTo(xAt(i), yOf(i));
      }
      return p;
    }

    Paint stroke(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = c;

    // Reps: gradient fill + line.
    final fill = Path.from(pathOf(yA))
      ..lineTo(xAt(a.length - 1), chart.bottom)
      ..lineTo(chart.left, chart.bottom)
      ..close();
    canvas
      ..drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorA.withValues(alpha: 0.3),
              colorA.withValues(alpha: 0),
            ],
          ).createShader(chart),
      )
      ..drawPath(pathOf(yA), stroke(colorA))
      // Weight line.
      ..drawPath(pathOf(yB), stroke(colorB));

    // Series labels above each line's peak.
    void peakLabel(
      String label,
      Color color,
      double Function(int) yOf,
      List<double> values,
    ) {
      var peak = 0;
      for (var i = 1; i < values.length; i++) {
        if (values[i] > values[peak]) peak = i;
      }
      final tp = _text(label, color, weight: FontWeight.w700);
      final x = (xAt(peak) - tp.width / 2).clamp(
        chart.left,
        chart.right - tp.width,
      );
      tp.paint(canvas, Offset(x, yOf(peak) - tp.height - 6));
    }

    peakLabel(labelA, colorA, yA, a);
    peakLabel(labelB, colorB, yB, b);

    // Month labels under the points.
    for (var i = 0; i < months.length; i++) {
      final tp = _text(months[i], monthTextColor);
      final x = (xAt(i) - tp.width / 2).clamp(
        chart.left - leftGutter / 2,
        size.width - tp.width,
      );
      tp.paint(canvas, Offset(x, chart.bottom + 8));
    }
  }

  @override
  bool shouldRepaint(_DualLinePainter old) =>
      old.a != a || old.b != b || old.months != months;
}

// ── Calorie rings — lifetime burn + weekly goal ──────────────────────

/// Lifetime-calorie milestone step: the outer ring fills toward the next
/// multiple of this.
const _kCalorieMilestone = 5000;

class _RingsSection extends ConsumerWidget {
  const _RingsSection({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final locale = Localizations.localeOf(context);
    final data = ref.watch(lifetimeChartDataProvider).asData?.value;
    final weekKcal = ref.watch(weeklyCaloriesProvider).asData?.value ?? 0;
    final goal = ref.watch(weeklyCalorieGoalProvider);
    final bodyFat = ref.watch(bodyFatPctProvider);
    final bodyFatStart = ref.watch(bodyFatStartPctProvider);

    final total = data?.totalCalories ?? 0;
    if (total <= 0) return const SizedBox.shrink();

    final compact = NumberFormat.compact(locale: locale.toString());
    final totalLabel = compact.format(total);
    final outer = (total % _kCalorieMilestone) / _kCalorieMilestone;
    final inner = goal == null || goal <= 0
        ? 0.0
        : (weekKcal / goal).clamp(0.0, 1.0);

    final dropped =
        bodyFat != null && bodyFatStart != null && bodyFatStart > bodyFat
        ? bodyFatStart - bodyFat
        : null;
    final droppedLabel = dropped == null
        ? null
        : (dropped == dropped.roundToDouble()
              ? '${dropped.round()}%'
              : '${dropped.toStringAsFixed(1)}%');

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: (AppSizes.contentPaddingH + 12).w,
      ),
      child: Column(
        children: [
          SizedBox(height: 56.h),
          Center(
            child: SizedBox(
              width: 200.w,
              height: 200.w,
              child: CustomPaint(
                painter: _RingsPainter(
                  outerFraction: outer,
                  innerFraction: inner,
                  outerColor: colors.accent,
                  innerColor: colors.trendPositive,
                  trackColor: colors.textSecondary.withValues(alpha: 0.15),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        totalLabel,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.calBurned,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          _Caption(
            text: droppedLabel != null
                ? l10n.statusCaloriesBodyFat(totalLabel, droppedLabel)
                : l10n.statusCaloriesBurnedTotal(totalLabel),
            highlights: {
              totalLabel: colors.accent,
              if (droppedLabel != null) droppedLabel: colors.trendPositive,
            },
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.outerFraction,
    required this.innerFraction,
    required this.outerColor,
    required this.innerColor,
    required this.trackColor,
  });
  final double outerFraction;
  final double innerFraction;
  final Color outerColor;
  final Color innerColor;
  final Color trackColor;

  void _ring(
    Canvas canvas,
    Offset center,
    double radius,
    double fraction,
    Color color,
    double width,
  ) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, stroke..color = trackColor);
    if (fraction <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      stroke..color = color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2 - 10;
    _ring(canvas, center, outerR, outerFraction, outerColor, 16);
    _ring(canvas, center, outerR - 24, innerFraction, innerColor, 13);
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.outerFraction != outerFraction || old.innerFraction != innerFraction;
}
