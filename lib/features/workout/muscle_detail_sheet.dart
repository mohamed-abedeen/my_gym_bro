import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';

import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/anatomy_body.dart';
import 'muscle_recovery_service.dart';
import 'workout_providers.dart';

/// Shows a full-screen modal with the anatomy body and muscle recovery details.
void showMuscleDetailSheet(BuildContext context) {
  showModalBottomSheet(
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
                color: Colors.white24,
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
                  'Muscle Recovery',
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
            ),
          ),

          SizedBox(height: 8.h),

          // Legend row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: colors.danger, label: 'Sore'),
                SizedBox(width: 12.w),
                _LegendDot(color: colors.amber, label: 'Recovering'),
                SizedBox(width: 12.w),
                _LegendDot(color: colors.success, label: 'Recovered'),
                SizedBox(width: 12.w),
                _LegendDot(color: colors.muscleUntrained, label: 'Untrained'),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Divider
          Divider(
            color: Colors.white12,
            height: 1,
            indent: 20.w,
            endIndent: 20.w,
          ),

          // Muscle list
          Expanded(
            child: muscleStates.when(
              data: (states) {
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
  final MuscleStateInfo muscle;
  const _MuscleRecoveryTile({required this.muscle});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recoveryText = _getRecoveryText();
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

  String _getRecoveryText() {
    if (muscle.state == MuscleState.undertrained) {
      return 'Not trained yet';
    }

    if (muscle.lastTrainedAt == null) return 'Not trained yet';

    final hoursSince =
        DateTime.now().difference(muscle.lastTrainedAt!).inMinutes / 60.0;

    if (muscle.state == MuscleState.recovered) {
      return 'Fully recovered — ready to train';
    }

    // Hours remaining until full recovery (per-muscle recovery time)
    final recoveryH = MuscleRecoveryService.recoveryHoursFor(muscle.muscleGroup);
    final hoursRemaining = (recoveryH - hoursSince).clamp(0.0, recoveryH);

    if (hoursRemaining < 1) {
      return 'Less than 1 hour to full recovery';
    } else if (hoursRemaining < 24) {
      return '${hoursRemaining.toInt()}h more rest needed';
    } else {
      final days = (hoursRemaining / 24).floor();
      final hours = (hoursRemaining % 24).toInt();
      if (hours == 0) {
        return '${days}d more rest needed';
      }
      return '${days}d ${hours}h more rest needed';
    }
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

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
