import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets/liquid_glass_button.dart';

/// Exercise detail / How-To screen — matches Figma "How to" frame.
///
/// Back + share header, "How to" title, large GIF,
/// circle thumbnail + name, and description text.
class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: back + share (glass circles) ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.contentPaddingH.w,
                  10.h,
                  AppSizes.contentPaddingH.w,
                  0,
                ),
                child: Row(
                  children: [
                    LiquidGlassButton(
                      width: 40.w,
                      height: 40.w,
                      opacity: 0.15,
                      radius: 20.r,
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.arrow_back_rounded,
                          color: colors.textPrimary, size: 20.sp),
                    ),
                    const Spacer(),
                    LiquidGlassButton(
                      width: 40.w,
                      height: 40.w,
                      opacity: 0.15,
                      radius: 20.r,
                      child: Icon(Icons.ios_share_rounded,
                          color: colors.textPrimary, size: 18.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // ── "How to" title ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Text(
                  l10n.howTo,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 30.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // ── Large GIF/image in rounded card ──
              if (exercise.gifUrl != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSizes.contentPaddingH.w,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.howtoGif.r),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors.panelBackground,
                        borderRadius:
                            BorderRadius.circular(AppRadius.howtoGif.r),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: exercise.gifUrl!,
                        width: double.infinity,
                        height: AppSizes.howtoGifH.h,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => Container(
                          height: AppSizes.howtoGifH.h,
                          decoration: BoxDecoration(
                            color: colors.panelBackground,
                            borderRadius:
                                BorderRadius.circular(AppRadius.howtoGif.r),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colors.accent,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: AppSizes.howtoGifH.h,
                          decoration: BoxDecoration(
                            color: colors.panelBackground,
                            borderRadius:
                                BorderRadius.circular(AppRadius.howtoGif.r),
                          ),
                          child: Center(
                            child: Icon(Icons.broken_image_rounded,
                                color: colors.textSecondary, size: 48.sp),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: 20.h),

              // ── Exercise name with circular thumbnail ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Row(
                  children: [
                    // Small circular thumbnail
                    ClipOval(
                      child: exercise.gifUrl != null
                          ? CachedNetworkImage(
                              imageUrl: exercise.gifUrl!,
                              width: 44.w,
                              height: 44.w,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _thumbPlaceholder(colors),
                              errorWidget: (_, __, ___) =>
                                  _thumbPlaceholder(colors),
                            )
                          : _thumbPlaceholder(colors),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              // ── Description / Instructions ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Text(
                  _buildDescription(),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
              SizedBox(height: 24.h),

              // ── Info sections ──
              if (_parseList(exercise.targetMuscles).isNotEmpty)
                _InfoSection(
                  title: l10n.targetMuscles,
                  chips: _parseList(exercise.targetMuscles),
                  chipColor: colors.accent,
                ),

              if (_parseList(exercise.secondaryMuscles).isNotEmpty)
                _InfoSection(
                  title: l10n.secondaryMuscles,
                  chips: _parseList(exercise.secondaryMuscles),
                  chipColor: colors.textSecondary,
                ),

              if (_parseList(exercise.equipments).isNotEmpty)
                _InfoSection(
                  title: l10n.equipment,
                  chips: _parseList(exercise.equipments),
                  chipColor: colors.textPrimary,
                ),

              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  String _buildDescription() {
    final instructions = _parseInstructions(exercise.instructions);
    if (instructions.isNotEmpty) return instructions.join(' ');
    return exercise.name;
  }

  List<String> _parseList(String? csv) {
    if (csv == null || csv.isEmpty) return [];
    return csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> _parseInstructions(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    var cleaned = raw;
    if (cleaned.startsWith('[')) cleaned = cleaned.substring(1);
    if (cleaned.endsWith(']')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    final lines = cleaned
        .split(RegExp(r'["\n]'))
        .map((s) => s.trim().replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), ''))
        .where((s) => s.isNotEmpty && s != ',')
        .toList();
    return lines;
  }

  Widget _thumbPlaceholder(AppColorsTheme colors) => Container(
        width: 44.w,
        height: 44.w,
        color: colors.separator,
        child: Icon(Icons.fitness_center_rounded,
            color: colors.textSecondary, size: 20.sp),
      );
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<String> chips;
  final Color chipColor;

  const _InfoSection({
    required this.title,
    required this.chips,
    required this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.contentPaddingH.w,
        right: AppSizes.contentPaddingH.w,
        bottom: 20.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: chips
                .map(
                  (c) => Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                          color: chipColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        color: chipColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Exercise Status Screen — post-workout view (Figma left screenshot)
//
// Shows: exercise GIF + name + time, sets table with weights/reps,
// stats cards (Volume, Avg Strength, Total Duration, Records),
// Cal Burned + Progress section, and bottom "Leg Day" banner.
// ═══════════════════════════════════════════════════════════════════

class ExerciseStatusScreen extends StatelessWidget {
  final Exercise exercise;

  /// Sets data: list of {weight, reps} maps.
  final List<Map<String, dynamic>> setsData;

  /// Stats
  final String duration;
  final String volume;
  final String avgStrength;
  final String records;
  final String calBurned;
  final String? sessionLabel;
  final String? nextSessionInfo;

  const ExerciseStatusScreen({
    super.key,
    required this.exercise,
    this.setsData = const [],
    this.duration = '5m',
    this.volume = '37170 lbs',
    this.avgStrength = '86',
    this.records = '5',
    this.calBurned = '250 cal',
    this.sessionLabel,
    this.nextSessionInfo,
  });

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 7.w),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.panelBackground,
                borderRadius: BorderRadius.circular(55.r),
              ),
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10.h),

                  // ── Header: back + share ──
                  Row(
                    children: [
                      LiquidGlassButton(
                        width: 48.w,
                        height: 48.w,
                        opacity: 0.15,
                        radius: 24.r,
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(Icons.arrow_back_rounded,
                            color: colors.textPrimary, size: 22.sp),
                      ),
                      const Spacer(),
                      LiquidGlassButton(
                        width: 48.w,
                        height: 48.w,
                        opacity: 0.15,
                        radius: 24.r,
                        child: Icon(Icons.ios_share_rounded,
                            color: colors.textPrimary, size: 20.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // ── Exercise name row: circular GIF + name + duration ──
                  Row(
                    children: [
                      // Circular GIF
                      ClipOval(
                        child: exercise.gifUrl != null
                            ? CachedNetworkImage(
                                imageUrl: exercise.gifUrl!,
                                width: 83.w,
                                height: 83.w,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    _circPlaceholder(colors, 83.w),
                                errorWidget: (_, __, ___) =>
                                    _circPlaceholder(colors, 83.w),
                              )
                            : _circPlaceholder(colors, 83.w),
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
                            ),
                            Text(
                              _currentTime(),
                              style: TextStyle(
                                color: colors.subtitleText,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        duration,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // ── Sets card (inner card bg) ──
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.cardElevated,
                      borderRadius: BorderRadius.circular(26.r),
                    ),
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        // Header row
                        _setsHeaderRow(colors),
                        SizedBox(height: 8.h),

                        // Set rows
                        ...(_effectiveSets().asMap().entries.map((entry) {
                          final i = entry.key;
                          final s = entry.value;
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 4.h),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50.w,
                                  child: Text(
                                    '${i + 1}',
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
                                      '${s['weight'] ?? '-'}',
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
                                  child: Text(
                                    '${s['reps'] ?? '-'}',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        })),

                        // ── Divider ──
                        Container(
                          height: 1,
                          color: colors.divider,
                          margin: EdgeInsets.symmetric(vertical: 12.h),
                        ),

                        // ── Stats rows ──
                        Row(
                          children: [
                            // Volume
                            Expanded(
                              child: _statBlock(colors,'Volume', volume, colors.success),
                            ),
                            // Avg Strength
                            Expanded(
                              child: _statBlock(colors,
                                  'Avg Strength', avgStrength, colors.success),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          children: [
                            // Total Duration
                            Expanded(
                              child: _statBlock(colors,
                                  'Total Duration', this.duration, colors.success),
                            ),
                            // Records
                            Expanded(
                              child:
                                  _statBlock(colors,'Records', records, colors.success),
                            ),
                          ],
                        ),

                        // ── Divider ──
                        Container(
                          height: 1,
                          color: colors.divider,
                          margin: EdgeInsets.symmetric(vertical: 12.h),
                        ),

                        // ── Cal Burned + Progress row ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cal burned section
                            Expanded(
                              child: Row(
                                children: [
                                  Text('🔥',
                                      style: TextStyle(fontSize: 28.sp)),
                                  SizedBox(width: 8.w),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cal Burned',
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                      Text(
                                        calBurned,
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
                            ),
                            // Progress section
                            Expanded(
                              child: Column(
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
                                  SizedBox(height: 4.h),
                                  // Progress bar placeholder
                                  Container(
                                    width: double.infinity,
                                    height: 26.h,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withValues(alpha: 0.35),
                                          Colors.white.withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _setsHeaderRow(AppColorsTheme colors) {
    return Row(
      children: [
        SizedBox(
          width: 50.w,
          child: Text('Sets',
              style: TextStyle(
                color: colors.subtitleText,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              )),
        ),
        Expanded(
          child: Center(
            child: Text('weights kg',
                style: TextStyle(
                  color: colors.subtitleText,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ),
        SizedBox(
          width: 50.w,
          child: Text('Rips',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.subtitleText,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              )),
        ),
      ],
    );
  }

  Widget _statBlock(AppColorsTheme colors, String label, String value, Color changeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 10.sp,
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
    );
  }

  List<Map<String, dynamic>> _effectiveSets() {
    if (setsData.isNotEmpty) return setsData;
    // Default demo data matching Figma
    return [
      {'weight': 90, 'reps': 8},
      {'weight': 80, 'reps': 10},
      {'weight': 70, 'reps': 12},
      {'weight': 60, 'reps': 4},
      {'weight': 50, 'reps': '-'},
    ];
  }

  String _currentTime() {
    final now = TimeOfDay.now();
    final hour = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'am' : 'pm';
    return '$hour:${minute}$period';
  }

  Widget _circPlaceholder(AppColorsTheme colors, double size) => Container(
        width: size,
        height: size,
        color: colors.separator,
        child: Icon(Icons.fitness_center_rounded,
            color: colors.textSecondary, size: size * 0.4),
      );
}
