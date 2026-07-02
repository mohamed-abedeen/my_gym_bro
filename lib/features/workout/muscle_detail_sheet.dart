import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/muscle_recovery_service.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/anatomy_body.dart';

/// Shows a full-screen modal with the anatomy body and muscle recovery details.
void showMuscleDetailSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _MuscleDetailSheet(),
  );
}

class _MuscleDetailSheet extends ConsumerWidget {
  const _MuscleDetailSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final muscleStates = ref.watch(muscleRecoveryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Handle bar
          Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.of(context).white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Text(
                  l10n.muscleRecovery,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: colors.textPrimary,
                      size: 18.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8.h),

          // Anatomy body
          muscleStates.when(
            data: (states) => AnatomyBody(
              muscleStates: states,
              height: 300.h,
              gender: ref.watch(anatomyGenderProvider),
              basePngPath: ref.watch(activeSkinPathProvider),
            ),
            loading: () => SizedBox(
              height: 300.h,
              child: Center(
                child: CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 2.w,
                ),
              ),
            ),
            error: (_, __) => AnatomyBody(
              muscleStates: const [],
              height: 300.h,
              gender: ref.watch(anatomyGenderProvider),
              basePngPath: ref.watch(activeSkinPathProvider),
            ),
          ),

          SizedBox(height: 8.h),

          // Legend row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: colors.danger, label: l10n.sore),
                SizedBox(width: 12.w),
                _LegendDot(color: colors.amber, label: l10n.recovering),
                SizedBox(width: 12.w),
                _LegendDot(color: colors.success, label: l10n.recovered),
                SizedBox(width: 12.w),
                _LegendDot(color: colors.muscleUntrained, label: l10n.undertrained),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Divider
          Divider(
            color: AppColors.of(context).white.withValues(alpha: 0.12),
            height: 1,
            indent: 20.w,
            endIndent: 20.w,
          ),

          // Muscle list
          Expanded(
            child: muscleStates.when(
              data: (states) {
                final weeklySets =
                    ref.watch(weeklySetsPerMuscleProvider).valueOrNull ??
                        const <String, double>{};
                // Sort: recovering first (most sore at top), then recovered, then untrained
                final sorted = [...states]..sort((a, b) {
                    final order = _stateOrder(a.state)
                        .compareTo(_stateOrder(b.state));
                    if (order != 0) return order;
                    // Within recovering: lowest recovery % (most sore) first
                    return (a.recoveryPercent ?? -1)
                        .compareTo(b.recoveryPercent ?? -1);
                  });

                // Filter out Cardio (no anatomy)
                final filtered = sorted
                    .where((m) => m.muscleGroup != 'Cardio')
                    .toList();

                return ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (_, i) => _MuscleRecoveryTile(
                    muscle: filtered[i],
                    l10n: l10n,
                    weeklySets: weeklySets[filtered[i].muscleGroup],
                  ),
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 2.w,
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

int _stateOrder(MuscleState state) => switch (state) {
      MuscleState.recovering => 0,
      MuscleState.recovered => 1,
      MuscleState.undertrained => 2,
    };

class _MuscleRecoveryTile extends StatelessWidget {
  const _MuscleRecoveryTile({
    required this.muscle,
    required this.l10n,
    this.weeklySets,
  });
  final MuscleStateInfo muscle;
  final AppLocalizations l10n;

  /// Weighted working sets accumulated this week (null/0 = none logged).
  final double? weeklySets;

  /// Evidence-based weekly hypertrophy volume band (sets per muscle).
  static const double _kMinEffectiveSets = 10;
  static const double _kMaxEffectiveSets = 20;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recoveryText = _getRecoveryText(l10n);
    final isUntrained = muscle.state == MuscleState.undertrained;
    final percentage = isUntrained
        ? '--'
        : '${((muscle.recoveryPercent ?? 0) * 100).toInt()}%';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: colors.cardElevated,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          // Color indicator
          Container(
            width: 4.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: muscle.color,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 12.w),

          // Muscle name + recovery info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  muscle.muscleGroup,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  recoveryText,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
                if (weeklySets != null && weeklySets! > 0) ...[
                  SizedBox(height: 2.h),
                  Text(
                    l10n.setsThisWeekCount(weeklySets!.round()),
                    style: TextStyle(
                      // Colour-code against the 10–20 weekly-set band:
                      // in range → green, over → amber, under → neutral.
                      color: weeklySets! > _kMaxEffectiveSets
                          ? colors.amber
                          : weeklySets! >= _kMinEffectiveSets
                              ? colors.success
                              : colors.textSecondary,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Recovery percentage
          Text(
            percentage,
            style: TextStyle(
              color: muscle.color,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _getRecoveryText(AppLocalizations l10n) {
    if (muscle.state == MuscleState.undertrained) {
      return l10n.notTrainedYet;
    }

    if (muscle.lastTrainedAt == null) return l10n.notTrainedYet;

    if (muscle.state == MuscleState.recovered) {
      return l10n.fullyRecovered;
    }

    // Hours remaining until the dose-adjusted recovery window closes.
    final recoveryH = muscle.recoveryHours ??
        MuscleRecoveryService.recoveryHoursFor(muscle.muscleGroup);
    final recoveredAt = muscle.recoveredAt;
    final hoursRemaining = recoveredAt == null
        ? 0.0
        : (recoveredAt.difference(DateTime.now()).inMinutes / 60.0)
            .clamp(0.0, recoveryH);

    if (hoursRemaining < 1) {
      return l10n.lessThanOneHourRecovery;
    } else if (hoursRemaining < 24) {
      return l10n.hoursRestNeeded(hoursRemaining.toInt());
    } else {
      final days = (hoursRemaining / 24).floor();
      final hours = (hoursRemaining % 24).toInt();
      if (hours == 0) {
        return l10n.daysRestNeeded(days);
      }
      return l10n.daysHoursRestNeeded(days, hours);
    }
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11.sp,
          ),
        ),
      ],
    );
  }
}
