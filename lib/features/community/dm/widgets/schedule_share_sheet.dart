import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/constants.dart';
import '../../../../shared/responsive.dart';
import '../../../workout/workout_providers.dart';

Future<void> showScheduleShareSheet(BuildContext context, {required Function(int id, String name, List<String> days) onShare}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ScheduleShareSheetContent(onShare: onShare),
  );
}

class _ScheduleShareSheetContent extends ConsumerWidget {
  final Function(int id, String name, List<String> days) onShare;

  const _ScheduleShareSheetContent({required this.onShare});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final schedulesAsync = ref.watch(allSchedulesProvider);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: colors.panelBackground.withValues(alpha: 0.9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet.r)),
          ),
          padding: EdgeInsets.all(AppSizes.contentPaddingH.w),
          child: Column(
            children: [
              SizedBox(height: 10.h),
              Text(
                AppLocalizations.of(context).dmShareSchedule,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20.h),
              Expanded(
                child: schedulesAsync.when(
                  data: (schedules) {
                    if (schedules.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context).dmNoSchedulesToShare,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: schedules.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];
                        return _ScheduleCard(
                          scheduleId: schedule.localId,
                          name: schedule.name,
                          onShare: onShare,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e', style: TextStyle(color: colors.danger))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends ConsumerWidget {
  final int scheduleId;
  final String name;
  final Function(int id, String name, List<String> days) onShare;

  const _ScheduleCard({
    required this.scheduleId,
    required this.name,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final daysAsync = ref.watch(scheduleDaysProvider(scheduleId));

    return GestureDetector(
      onTap: () {
        final daysStr = daysAsync.maybeWhen(
          data: (days) => days.map((d) => d.isRestDay ? 'Rest' : (d.label ?? 'Day')).toList(),
          orElse: () => <String>[],
        );
        onShare(scheduleId, name, daysStr);
        Navigator.of(context).pop();
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: colors.cardElevated,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: colors.separator),
        ),
        child: Row(
          children: [
            Icon(Icons.fitness_center_rounded, color: colors.accent, size: 24.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  daysAsync.when(
                    data: (days) => Text(
                      AppLocalizations.of(context).dmDaysCount(days.length),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.sp,
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Icon(Icons.ios_share_rounded, color: colors.textSecondary, size: 20.sp),
          ],
        ),
      ),
    );
  }
}
