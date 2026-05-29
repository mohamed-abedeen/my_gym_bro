import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Show the Status bottom sheet — Figma "Status" screen.
void showStatusBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _StatusSheet(),
  );
}


class _StatusSheet extends ConsumerWidget {
  const _StatusSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet.r),
          ),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(bottom: 40.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              SizedBox(height: 12.h),
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // ── Header: X  ...  share + check ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Row(
                  children: [
                    // Close (glass circle 48x48)
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.15,
                      radius: 24.r,
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close_rounded,
                          color: colors.textPrimary, size: 22.sp),
                    ),
                    const Spacer(),
                    // Share (glass circle 48x48)
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.15,
                      radius: 24.r,
                      child: Icon(Icons.ios_share_rounded,
                          color: colors.textPrimary, size: 20.sp),
                    ),
                    SizedBox(width: 10.w),
                    // Check (accent glass circle 48x48)
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.25,
                      radius: 24.r,
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.check_rounded,
                          color: colors.accent, size: 22.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // "Status" title — 24px bold per Figma
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (AppSizes.contentPaddingH + 4).w,
                ),
                child: Text(
                  l10n.status,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // ── Body Status card ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: _BodyStatusCard(l10n: l10n),
              ),
              SizedBox(height: 16.h),

              // ── Workout Status card ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: _WorkoutStatusCard(l10n: l10n),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Body Status Card — Figma: #29292B bg, radius 25
// "Body Status" 24px bold
// Rows: Today/250cal, Last week/1250cal, Last Month/5125cal
// ═══════════════════════════════════════════════════════════════════

class _BodyStatusCard extends ConsumerWidget {
  const _BodyStatusCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final activity = ref.watch(activityStatsProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(25.r),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.bodyStatus,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16.h),
          activity.when(
            data: (a) => Column(
              children: [
                _ActivityRow(
                  label: l10n.today,
                  value: '${a.todayCalories} cal',
                  positive: a.todayCalories > 0,
                ),
                SizedBox(height: 10.h),
                _ActivityRow(
                  label: l10n.lastWeek,
                  value: '${a.weekCalories} cal',
                  positive: a.weekCalories > 0,
                ),
                SizedBox(height: 10.h),
                _ActivityRow(
                  label: l10n.lastMonth,
                  value: '${a.monthCalories} cal',
                  positive: a.monthCalories > 0,
                ),
              ],
            ),
            loading: () => SizedBox(
              height: 120.h,
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 2.w,
                ),
              ),
            ),
            error: (_, __) => SizedBox(height: 120.h),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.label,
    required this.value,
    required this.positive,
  });
  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // Only draw an up-arrow when there's activity in the period —
        // an empty period shouldn't look like a positive trend.
        if (positive)
          Transform.rotate(
            angle: AppAngles.quarterTurnCcw,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: colors.trendPositive,
              size: 24.sp,
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Workout Status Card — Figma: #29292B bg, radius 25
// "Workout Status" 24px bold
// Rows: Volume, Total Duration (with 120%), Avg Strength (with 5+),
//        Records (with -2 red)
// ═══════════════════════════════════════════════════════════════════

class _WorkoutStatusCard extends ConsumerWidget {
  const _WorkoutStatusCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    // Show lifetime totals (not just this week) so the user sees the
    // accumulated effort from every finished session.
    final stats = ref.watch(lifetimeStatsProvider);
    final records = ref.watch(recordsProvider);
    final unit = ref.watch(weightUnitProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(25.r),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.workoutStatus,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16.h),
          stats.when(
            data: (s) => Column(
              children: [
                _WorkoutStatRow(
                  label: l10n.volume,
                  value: formatWeight(
                    s.totalVolume,
                    unit,
                    decimals: 0,
                    withUnit: true,
                  ),
                ),
                SizedBox(height: 10.h),
                _WorkoutStatRow(
                  label: l10n.totalDuration,
                  value: s.formattedDuration,
                ),
                SizedBox(height: 10.h),
                _WorkoutStatRow(
                  label: l10n.avgStrength,
                  value: formatWeight(
                    s.avgStrength,
                    unit,
                    decimals: 0,
                    withUnit: true,
                  ),
                ),
                SizedBox(height: 10.h),
                _WorkoutStatRow(
                  label: l10n.records,
                  value: '${records.asData?.value.count ?? 0}',
                  trend: records.asData?.value.trend?.toDouble(),
                ),
              ],
            ),
            loading: () => SizedBox(
              height: 180.h,
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 2.w,
                ),
              ),
            ),
            error: (_, __) => SizedBox(height: 180.h),
          ),
        ],
      ),
    );
  }
}

class _WorkoutStatRow extends StatelessWidget {

  const _WorkoutStatRow({
    required this.label,
    required this.value,
    this.trend,
  });
  final String label;
  final String value;
  final double? trend;

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
                  color: colors.textPrimary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (trend != null && trend != 0) ...[
          Text(
            '${trend! >= 0 ? '+' : ''}${trend!.toInt()}',
            style: TextStyle(
              color: isPositive
                  ? colors.trendPositive
                  : colors.trendNegative,
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(width: 2.w),
          Transform.rotate(
            angle: isPositive ? AppAngles.quarterTurnCcw : AppAngles.quarterTurnCw,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: isPositive
                  ? colors.trendPositive
                  : colors.trendNegative,
              size: 24.sp,
            ),
          ),
        ] else if (trend == 0) ...[
          // Show a neutral indicator instead of suppressing the row entirely,
          // so the column stays aligned across rows with mixed trend states.
          Text(
            '0',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}
