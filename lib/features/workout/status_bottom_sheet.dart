import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/liquid_glass_button.dart';
import 'workout_providers.dart';

/// Show the Status bottom sheet — Figma "Status" screen.
void showStatusBottomSheet(BuildContext context) {
  showModalBottomSheet(
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

class _BodyStatusCard extends StatelessWidget {
  final AppLocalizations l10n;
  const _BodyStatusCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
          _CalRow(label: l10n.today, value: '250 cal'),
          SizedBox(height: 10.h),
          _CalRow(label: l10n.lastWeek, value: '1250 cal'),
          SizedBox(height: 10.h),
          _CalRow(label: l10n.lastMonth, value: '5125 cal'),
        ],
      ),
    );
  }
}

class _CalRow extends StatelessWidget {
  final String label;
  final String value;
  const _CalRow({required this.label, required this.value});

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
        // Trend arrow (up-right)
        Transform.rotate(
          angle: -1.5708,
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
  final AppLocalizations l10n;
  const _WorkoutStatusCard({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final stats = ref.watch(weeklyStatsProvider);
    final profile = ref.watch(userProfileProvider);
    final weightUnit = profile.when(
      data: (p) => p?.weightUnit ?? 'lbs',
      loading: () => 'lbs',
      error: (_, __) => 'lbs',
    );

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
                  value: '${s.totalVolume.toInt()}  $weightUnit',
                  trend: s.volumeTrend,
                ),
                SizedBox(height: 10.h),
                _WorkoutStatRow(
                  label: l10n.totalDuration,
                  value: s.formattedDuration,
                  trend: s.durationTrend,
                  trendSuffix: '%',
                ),
                SizedBox(height: 10.h),
                _WorkoutStatRow(
                  label: l10n.avgStrength,
                  value: '${s.avgStrength.toInt()}',
                  trend: s.strengthTrend,
                ),
                SizedBox(height: 10.h),
                _WorkoutStatRow(
                  label: l10n.records,
                  value: '5',
                  trend: -2,
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
  final String label;
  final String value;
  final double? trend;
  final String trendSuffix;

  const _WorkoutStatRow({
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
        if (trend != null) ...[
          Text(
            '${trend! >= 0 ? '' : ''}${trend!.toInt()}$trendSuffix',
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
            angle: isPositive ? -1.5708 : 1.5708,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: isPositive
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
