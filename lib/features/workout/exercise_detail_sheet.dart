import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/liquid_glass_button.dart';
import 'workout_providers.dart';

/// Show exercise detail bottom sheet — Figma "ExerciseStatusAfterFinishing".
void showExerciseDetailSheet(
  BuildContext context, {
  required SessionExerciseDetail exercise,
  required Session session,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExerciseDetailSheet(
      exercise: exercise,
      session: session,
    ),
  );
}


class _ExerciseDetailSheet extends ConsumerWidget {
  final SessionExerciseDetail exercise;
  final Session session;

  const _ExerciseDetailSheet({
    required this.exercise,
    required this.session,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(userProfileProvider);
    final weightUnit = profile.whenOrNull(data: (p) => p?.weightUnit) ?? 'kg';

    final timeStr = exercise.startedAt != null
        ? DateFormat('h:mma').format(exercise.startedAt!).toLowerCase()
        : '';

    // Calculate exercise duration (rough estimate from sets)
    final durationMin = exercise.setDetails.length * 2; // ~2 min per set

    // Session-level stats
    final sessionVolume = session.totalVolume?.toInt() ?? 0;
    final sessionDurationMin = (session.durationSeconds ?? 0) ~/ 60;
    final sessionHours = sessionDurationMin ~/ 60;
    final sessionMins = sessionDurationMin % 60;
    final durationStr = sessionHours > 0
        ? '${sessionHours}h ${sessionMins}m'
        : '${sessionMins}m';

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

              // ── Header: back + share ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Row(
                  children: [
                    // Back button
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.15,
                      radius: 24.r,
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: colors.textPrimary,
                        size: 20.sp,
                      ),
                    ),
                    const Spacer(),
                    // Share button
                    LiquidGlassButton(
                      width: 48.w,
                      height: 48.h,
                      opacity: 0.15,
                      radius: 24.r,
                      child: Icon(
                        Icons.ios_share_rounded,
                        color: colors.textPrimary,
                        size: 20.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // ── Exercise info: GIF + name + time + duration ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Row(
                  children: [
                    // Circular GIF — 83x82 per Figma
                    ClipOval(
                      child: exercise.gifUrl != null
                          ? CachedNetworkImage(
                              imageUrl: exercise.gifUrl!,
                              width: 83.w,
                              height: 82.h,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 83.w,
                                height: 82.h,
                                color: colors.separator,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 83.w,
                                height: 82.h,
                                color: colors.separator,
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  color: colors.textSecondary,
                                  size: 32.sp,
                                ),
                              ),
                            )
                          : Container(
                              width: 83.w,
                              height: 82.h,
                              color: colors.separator,
                              child: Icon(
                                Icons.fitness_center_rounded,
                                color: colors.textSecondary,
                                size: 32.sp,
                              ),
                            ),
                    ),
                    SizedBox(width: 14.w),
                    // Name + time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Duration
                    Text(
                      '${durationMin}m',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // ── Sets table card ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.cardElevated,
                    borderRadius: BorderRadius.circular(26.r),
                  ),
                  padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 20.h),
                  child: Column(
                    children: [
                      // Table header
                      Row(
                        children: [
                          SizedBox(
                            width: 50.w,
                            child: Text(
                              l10n.sets,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '${l10n.weight} $weightUnit',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 50.w,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                l10n.reps,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // Set rows
                      ...exercise.setDetails.map((s) {
                        final weightStr = s.weight != null
                            ? s.weight!.toInt().toString()
                            : '-';
                        final repsStr =
                            s.reps != null ? s.reps.toString() : '-';

                        return Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50.w,
                                child: Text(
                                  '${s.setIndex + 1}',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    weightStr,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 50.w,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    repsStr,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Separator
                      SizedBox(height: 8.h),
                      Container(
                        height: 1.h,
                        color: colors.divider,
                      ),
                      SizedBox(height: 16.h),

                      // ── Stats grid: Volume, Avg Strength, Duration, Records ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StatItem(
                                  label: l10n.volume,
                                  value: '$sessionVolume lbs',
                                ),
                                SizedBox(height: 12.h),
                                _StatItem(
                                  label: l10n.totalDuration,
                                  value: durationStr,
                                  trend: '120%',
                                  trendPositive: true,
                                ),
                              ],
                            ),
                          ),
                          // Right column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StatItem(
                                  label: l10n.avgStrength,
                                  value: '86',
                                  trend: '5+',
                                  trendPositive: true,
                                ),
                                SizedBox(height: 12.h),
                                _StatItem(
                                  label: 'Records',
                                  value: '5',
                                  trend: '-2',
                                  trendPositive: false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Separator
                      SizedBox(height: 16.h),
                      Container(
                        height: 1.h,
                        color: colors.divider,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // ── Bottom row: Cal Burned + Progress ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (AppSizes.contentPaddingH + 4).w,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cal Burned
                    Row(
                      children: [
                        Text(
                          '\u{1F525}',
                          style: TextStyle(fontSize: 28.sp),
                        ),
                        SizedBox(width: 8.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cal Burned',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '${exercise.setDetails.length * 50} cal',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Progress mini chart placeholder
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROGRESS',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // Mini progress chart placeholder
                        SizedBox(
                          width: 146.w,
                          height: 26.h,
                          child: CustomPaint(
                            painter: _MiniChartPainter(),
                          ),
                        ),
                      ],
                    ),
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

/// Single stat item with optional trend indicator.
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final bool trendPositive;

  const _StatItem({
    required this.label,
    required this.value,
    this.trend,
    this.trendPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
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
        Row(
          children: [
            Text(
              value,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (trend != null) ...[
              SizedBox(width: 6.w),
              Text(
                trend!,
                style: TextStyle(
                  color: trendPositive
                      ? colors.trendPositive
                      : colors.trendNegative,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(width: 2.w),
              Transform.rotate(
                angle: trendPositive ? -1.5708 : 1.5708,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: trendPositive
                      ? colors.trendPositive
                      : colors.trendNegative,
                  size: 18.sp,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Paints a simple mini progress line chart.
class _MiniChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Simulated progress data points
    final points = [0.4, 0.6, 0.3, 0.7, 0.5, 0.8, 0.6, 0.9, 0.7, 0.85];
    final path = Path();
    final stepX = size.width / (points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Dashed line effect
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      dashPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
