import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/features/exercises/exercise_detail_screen.dart';
import 'package:my_gym_bro/features/schedule/split_providers.dart';
import 'package:my_gym_bro/features/schedule/split_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Day Detail — one training day of the split: anatomy hero with the day's
/// muscles, quick stats, the exercise list and a Discover CTA.
class DayDetailScreen extends ConsumerWidget {
  const DayDetailScreen({required this.scheduleDayId, super.key});
  final int scheduleDayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    final day = ref.watch(scheduleDayProvider(scheduleDayId)).valueOrNull;
    final exercises =
        ref.watch(dayExercisesProvider(scheduleDayId)).valueOrNull ??
            const <DayExercise>[];
    final muscles = dayMuscleGroups(exercises);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: day == null
            ? Center(
                child: CircularProgressIndicator(
                  color: colors.accent,
                  strokeWidth: 2.w,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero: anatomy behind header + title block ──
                    // Clip.none lets the body flow under the stats row below.
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: 0,
                          right: -20.w,
                          child: SplitHeroBody(muscles: muscles),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppSizes.contentPaddingH.w,
                                8.h,
                                AppSizes.contentPaddingH.w,
                                0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  SplitHeaderButton(
                                    icon: Icons.arrow_back_rounded,
                                    onTap: () => Navigator.of(context).pop(),
                                  ),
                                  SplitHeaderButton(
                                    icon: Icons.edit_rounded,
                                    onTap: () => context.push(
                                      AppRoutes.scheduleBuilder,
                                      extra: day.scheduleId,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 28.h),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSizes.contentPaddingH.w,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 260.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 10.w,
                                      runSpacing: 6.h,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          day.label ??
                                              l10n.dayNumber(
                                                day.dayIndex + 1,
                                              ),
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 38.sp,
                                            fontWeight: FontWeight.w800,
                                            height: 1.1,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 5.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.accent
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(14.r),
                                          ),
                                          child: Text(
                                            l10n.dayDetailCurrentPlan,
                                            style: TextStyle(
                                              color: colors.accent,
                                              fontSize: 12.5.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10.h),
                                    Text(
                                      muscles.isEmpty
                                          ? l10n.splitDescription
                                          : l10n.dayDetailDescription(
                                              muscles.take(3).join(', '),
                                            ),
                                      style: TextStyle(
                                        color: colors.subtitleText,
                                        fontSize: 14.sp,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.contentPaddingH.w,
                      ),
                      child: _DayStatsRow(
                        l10n: l10n,
                        day: day,
                        exerciseCount: exercises.length,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.contentPaddingH.w,
                      ),
                      child: _WorkoutCard(l10n: l10n, exercises: exercises),
                    ),
                    SizedBox(height: 16.h),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSizes.contentPaddingH.w,
                      ),
                      child: _DiscoverCta(l10n: l10n),
                    ),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Stats: Duration · Exercises · Calories · Progress ──
class _DayStatsRow extends ConsumerWidget {
  const _DayStatsRow({
    required this.l10n,
    required this.day,
    required this.exerciseCount,
  });
  final AppLocalizations l10n;
  final ScheduleDay day;
  final int exerciseCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = exerciseCount == 0 ? 1 : exerciseCount;
    final (minMin, minMax) = estimateSessionMinutes(count);
    final (kcalMin, kcalMax) = estimateSessionKcal(count);
    final progress =
        ref.watch(scheduleCycleProgressProvider(day.scheduleId)).valueOrNull ??
            0.0;

    return Row(
      children: [
        _DayStatCard(
          icon: Icons.schedule_rounded,
          label: l10n.splitStatDuration,
          value: l10n.splitMinutesRange(minMin, minMax),
        ),
        SizedBox(width: 8.w),
        _DayStatCard(
          icon: Icons.fitness_center_rounded,
          label: l10n.exercisesLabel,
          value: '$exerciseCount',
          sub: l10n.exercisesLabel,
        ),
        SizedBox(width: 8.w),
        _DayStatCard(
          icon: Icons.local_fire_department_rounded,
          label: l10n.dayDetailStatCalories,
          value: '$kcalMin–$kcalMax',
          sub: l10n.dayDetailKcalApprox,
        ),
        SizedBox(width: 8.w),
        _DayStatCard(
          icon: Icons.trending_up_rounded,
          label: l10n.splitStatProgress,
          value: '${(progress * 100).round()}%',
          progress: progress,
        ),
      ],
    );
  }
}

class _DayStatCard extends StatelessWidget {
  const _DayStatCard({
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
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.separator, width: 0.7),
          borderRadius: BorderRadius.circular(20.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13.sp, color: colors.textSecondary),
                SizedBox(width: 4.w),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // Scale down instead of truncating — ranges like "45–60 min."
            // must stay readable in a quarter-width card.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: 4.h),
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
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 10.5.sp,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Exercise list card ──
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.l10n, required this.exercises});
  final AppLocalizations l10n;
  final List<DayExercise> exercises;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
      ),
      padding: EdgeInsets.fromLTRB(14.w, 18.h, 14.w, 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l10n.dayDetailWorkoutHeader,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: colors.cardElevated,
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  l10n.premadeExercisesCount(exercises.length),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          for (var i = 0; i < exercises.length; i++) ...[
            if (i > 0)
              SizedBox(
                width: double.infinity,
                height: 1,
                child: ColoredBox(color: colors.cardElevated),
              ),
            _ExerciseRow(l10n: l10n, index: i, item: exercises[i]),
          ],
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.l10n,
    required this.index,
    required this.item,
  });
  final AppLocalizations l10n;
  final int index;
  final DayExercise item;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final exercise = item.exercise;

    Widget placeholder() => ColoredBox(
          color: colors.cardElevated,
          child: Icon(
            Icons.fitness_center_rounded,
            size: 22.sp,
            color: colors.textSecondary,
          ),
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: exercise == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExerciseDetailScreen(exercise: exercise),
                ),
              ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 30.w,
              height: 30.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.accent, width: 1.5),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.exerciseThumb.r),
              child: SizedBox(
                width: AppSizes.thumbStandard.w,
                height: AppSizes.thumbStandard.w,
                child: exercise?.gifUrl != null
                    ? CachedNetworkImage(
                        cacheManager: ExerciseGifCache.instance,
                        imageUrl: exercise!.gifUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 140,
                        memCacheHeight: 140,
                        placeholder: (_, __) => placeholder(),
                        errorWidget: (_, __, ___) => placeholder(),
                      )
                    : placeholder(),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise?.name ?? item.scheduled.exerciseId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    exercise?.muscleGroup ?? '',
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
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.setsCount(item.scheduled.targetSets),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  l10n.dayDetailRepsCount(item.scheduled.targetReps),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5.sp,
                  ),
                ),
              ],
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.chevron_right_rounded,
              size: 20.sp,
              color: colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width accent CTA → Discover Programs.
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
