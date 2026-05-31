import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/services/exercise_gif_cache.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// Show exercise detail bottom sheet — Figma "ExerciseStatusAfterFinishing".
void showExerciseDetailSheet(
  BuildContext context, {
  required SessionExerciseDetail exercise,
  required Session session,
}) {
  showModalBottomSheet<void>(
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
  const _ExerciseDetailSheet({
    required this.exercise,
    required this.session,
  });

  final SessionExerciseDetail exercise;
  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final unit = ref.watch(weightUnitProvider);
    final weightUnit = weightUnitLabel(unit);

    final timeStr = exercise.startedAt != null
        ? DateFormat('h:mma').format(exercise.startedAt!).toLowerCase()
        : '';

    final durationMin = exercise.setDetails.length * 2;

    final sessionVolumeStr = formatWeight(
      session.totalVolume,
      unit,
      decimals: 0,
      withUnit: true,
    );
    final sessionDurationMin = (session.durationSeconds ?? 0) ~/ 60;
    final sessionHours = sessionDurationMin ~/ 60;
    final sessionMins = sessionDurationMin % 60;
    final durationStr = sessionHours > 0
        ? '${sessionHours}h ${sessionMins}m'
        : '${sessionMins}m';

    final estimatedCal = exercise.setDetails.length * 50;

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

              // ── Top nav: back + share ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Row(
                  children: [
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

              // ── Header: avatar + name/time + duration ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Row(
                  children: [
                    ClipOval(
                      child: exercise.gifUrl != null
                          ? CachedNetworkImage(
                              cacheManager: ExerciseGifCache.instance,
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

              // ── Main card: table + stats + cal + progress ──
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sets table header
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
                            ? formatWeight(s.weight, unit, decimals: 0)
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

                      // Divider after table
                      SizedBox(height: 8.h),
                      Container(height: 1.h, color: colors.divider),
                      SizedBox(height: 16.h),

                      // 2x2 Stats grid
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StatItem(
                                  label: l10n.volume,
                                  value: sessionVolumeStr,
                                  trend: '↗',
                                ),
                                SizedBox(height: 12.h),
                                _StatItem(
                                  label: l10n.totalDuration,
                                  value: durationStr,
                                  trend: '120% ↗',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StatItem(
                                  label: l10n.avgStrength,
                                  value: '86',
                                  trend: '5+ ↗',
                                ),
                                SizedBox(height: 12.h),
                                const _StatItem(
                                  label: 'Records',
                                  value: '5',
                                  trend: '-2 ↘',
                                  trendPositive: false,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Divider before bottom section
                      SizedBox(height: 16.h),
                      Container(height: 1.h, color: colors.divider),
                      SizedBox(height: 16.h),

                      // Cal Burned + Progress (inside card)
                      Row(
                        children: [
                          // Fire + cal info
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
                                      color: colors.textSecondary,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '$estimatedCal cal',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Progress mini chart
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROGRESS',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              SizedBox(
                                width: 146.w,
                                height: 36.h,
                                child: ref
                                    .watch(exerciseVolumeHistoryProvider(
                                      exercise.exerciseId,
                                    ))
                                    .whenData(
                                      (pts) => CustomPaint(
                                        painter: _MiniChartPainter(points: pts),
                                      ),
                                    )
                                    .valueOrNull ??
                                    const CustomPaint(
                                      painter: _MiniChartPainter(),
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

/// Single stat item with optional trend badge.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    this.trend,
    this.trendPositive = true,
  });

  final String label;
  final String value;
  final String? trend;
  final bool trendPositive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
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
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trend != null) ...[
              SizedBox(width: 5.w),
              Text(
                trend!,
                style: TextStyle(
                  color: trendPositive
                      ? colors.trendPositive
                      : colors.trendNegative,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Minimalist sparkline area chart: white line, gradient fill, dashed baseline.
class _MiniChartPainter extends CustomPainter {
  const _MiniChartPainter({List<double>? points}) : _raw = points;

  static const _fallback = [0.4, 0.6, 0.3, 0.7, 0.5, 0.8, 0.6, 0.9, 0.7, 0.85];
  final List<double>? _raw;

  /// Normalise raw volume values to [0, 1]. Falls back to placeholder data.
  List<double> get _points {
    final raw = _raw;
    final src = (raw == null || raw.length < 2) ? _fallback : raw;
    final minV = src.reduce((a, b) => a < b ? a : b);
    final maxV = src.reduce((a, b) => a > b ? a : b);
    if (maxV == minV) return src.map((_) => 0.5).toList();
    return src.map((v) => (v - minV) / (maxV - minV)).toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final points = _points;
    final stepX = size.width / (points.length - 1);

    // Build line path
    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    // Gradient fill below the line
    final fillPath = Path()
      ..addPath(linePath, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.25),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // White line on top
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Dashed baseline at bottom
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const dashWidth = 4.0;
    const dashGap = 3.0;
    var x = 0.0;
    final baselineY = size.height;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, baselineY),
        Offset((x + dashWidth).clamp(0, size.width), baselineY),
        dashPaint,
      );
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter old) => old._raw != _raw;
}
