import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/progress_reports_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// The periodic Reports window (PRD §5.17): server-generated weekly/monthly
/// summaries with ▲/▼ deltas vs the previous period, browsable offline via
/// the `ProgressReports` mirror. Reached from Workout → Status sheet →
/// Reports. (Distinct from `ReportsScreen`, the per-day/week drill-down.)
class PeriodicReportsScreen extends ConsumerStatefulWidget {
  const PeriodicReportsScreen({super.key});

  @override
  ConsumerState<PeriodicReportsScreen> createState() =>
      _PeriodicReportsScreenState();
}

class _PeriodicReportsScreenState
    extends ConsumerState<PeriodicReportsScreen> {
  String _type = 'weekly';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final reports = ref.watch(periodReportsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.reports,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.02 * 26.sp,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: AppSizes.headerActionBtn.w,
                      height: AppSizes.headerActionBtn.w,
                      decoration: BoxDecoration(
                        color: colors.cardElevated,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: colors.textPrimary,
                        size: AppSizes.headerActionIcon.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Weekly | Monthly
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
              child: Row(
                children: [
                  for (final (type, label) in [
                    ('weekly', l10n.boardWeekly),
                    ('monthly', l10n.boardMonthly),
                  ]) ...[
                    _TypePill(
                      label: label,
                      active: _type == type,
                      colors: colors,
                      onTap: () => setState(() => _type = type),
                    ),
                    SizedBox(width: 8.w),
                  ],
                ],
              ),
            ),

            Expanded(
              child: reports.when(
                data: (all) {
                  final list =
                      all.where((r) => r.periodType == _type).toList();
                  if (list.isEmpty) return _Empty(l10n: l10n, colors: colors);
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 40.h),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (_, i) => _ReportCard(
                      report: list[i],
                      l10n: l10n,
                      colors: colors,
                    ),
                  );
                },
                loading: () => Center(
                  child: CircularProgressIndicator(
                    color: colors.accent,
                    strokeWidth: 2.w,
                  ),
                ),
                error: (_, __) => _Empty(l10n: l10n, colors: colors),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n, required this.colors});
  final AppLocalizations l10n;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Text(
          l10n.reportsEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.active,
    required this.colors,
    required this.onTap,
  });
  final String label;
  final bool active;
  final AppColorsTheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: active ? colors.cardElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: active ? colors.accent : colors.separator,
            width: active ? 2.w : 1.w,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({
    required this.report,
    required this.l10n,
    required this.colors,
  });
  final PeriodReport report;
  final AppLocalizations l10n;
  final AppColorsTheme colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider);
    final locale = Localizations.localeOf(context);
    final fmt = NumberFormat.decimalPattern(locale.toString());
    final dateFmt = DateFormat.MMMd(locale.languageCode);
    final unitLabel = weightUnitLabel(unit);

    String weight(double kg) =>
        '${fmt.format(convertFromKg(kg, unit).round())} $unitLabel';
    String count(double v) => fmt.format(v.round());

    final rows = <(String, String, double)>[
      (
        l10n.volumeLabel,
        weight(report.metric('volume_kg')),
        report.delta('volume_kg'),
      ),
      (
        l10n.reportSessions,
        count(report.metric('sessions')),
        report.delta('sessions'),
      ),
      (
        l10n.reportTrainingDays,
        count(report.metric('training_days')),
        report.delta('training_days'),
      ),
      (l10n.sets, count(report.metric('sets')), report.delta('sets')),
      (
        l10n.reportPrs,
        count(report.metric('pr_count')),
        report.delta('pr_count'),
      ),
      if (report.metric('challenge_points') > 0 ||
          report.delta('challenge_points') != 0)
        (
          l10n.reportChallengePoints,
          count(report.metric('challenge_points')),
          report.delta('challenge_points'),
        ),
    ];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dateFmt.format(report.periodStart)} – '
            '${dateFmt.format(report.periodEnd)}',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10.h),
          for (final (label, value, delta) in rows) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _DeltaChip(
                    delta: delta,
                    isWeight: label == l10n.volumeLabel,
                    colors: colors,
                    fmt: fmt,
                    unit: unit,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "▲ 1,240 kg" / "▼ 2" / "—" vs the previous period.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.delta,
    required this.isWeight,
    required this.colors,
    required this.fmt,
    required this.unit,
  });
  final double delta;
  final bool isWeight;
  final AppColorsTheme colors;
  final NumberFormat fmt;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    // Round the DISPLAY magnitude first — a sub-unit delta (e.g. +0.3 kg)
    // must show the em-dash, not "▲ 0 kg".
    final rounded =
        (isWeight ? convertFromKg(delta.abs(), unit) : delta.abs()).round();
    if (rounded == 0) {
      return Text(
        '—',
        style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
      );
    }
    final up = delta > 0;
    final magnitude = isWeight
        ? '${fmt.format(rounded)} ${weightUnitLabel(unit)}'
        : fmt.format(rounded);
    return Text(
      '${up ? '▲' : '▼'} $magnitude',
      style: TextStyle(
        color: up ? colors.success : colors.danger,
        fontSize: 12.sp,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
