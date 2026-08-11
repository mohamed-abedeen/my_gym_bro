import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/router/app_router.dart';
import 'package:my_gym_bro/features/schedule/premade_programs.dart';
import 'package:my_gym_bro/features/schedule/premade_programs_screen.dart';
import 'package:my_gym_bro/features/schedule/split_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Discover Programs — featured picks from the premade catalog with a link
/// into the full library. Filter chips are visual-only for now.
class DiscoverProgramsScreen extends ConsumerWidget {
  const DiscoverProgramsScreen({super.key});

  /// One program per level (beginner → advanced), topped up to three.
  static List<PremadeProgram> _featured() {
    final picks = <PremadeProgram>[];
    for (final level in PremadeLevel.values) {
      for (final p in premadePrograms) {
        if (p.level == level) {
          picks.add(p);
          break;
        }
      }
    }
    for (final p in premadePrograms) {
      if (picks.length >= 3) break;
      if (!picks.contains(p)) picks.add(p);
    }
    return picks.take(3).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final featured = _featured();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: back + centered title ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.contentPaddingH.w,
                  8.h,
                  AppSizes.contentPaddingH.w,
                  0,
                ),
                child: SizedBox(
                  height: 48.w,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SplitHeaderButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Center(
                        child: Text(
                          l10n.discoverTitle,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Text(
                  l10n.discoverProgramsTitle,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 34.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              // ── Filter chips (visual-only) ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: l10n.discoverFilter,
                      leading: Icons.tune_rounded,
                    ),
                    SizedBox(width: 8.w),
                    _FilterChip(label: l10n.discoverLevel, dropdown: true),
                    SizedBox(width: 8.w),
                    _FilterChip(label: l10n.discoverGoal, dropdown: true),
                    SizedBox(width: 8.w),
                    _FilterChip(
                      label: l10n.discoverEquipment,
                      dropdown: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              // ── Featured program cards ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Column(
                  children: [
                    for (final program in featured) ...[
                      _ProgramCard(l10n: l10n, program: program),
                      SizedBox(height: 14.h),
                    ],
                  ],
                ),
              ),
              // ── Show all → full premade library ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.premadePrograms),
                  child: Container(
                    height: 56.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.panelBackground,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      l10n.discoverShowAll(premadePrograms.length),
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 15.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              // ── Coach card ──
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSizes.contentPaddingH.w,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.panelBackground,
                    borderRadius: BorderRadius.circular(AppRadius.card.r),
                  ),
                  padding: EdgeInsets.all(18.w),
                  child: Row(
                    children: [
                      Container(
                        width: 52.w,
                        height: 52.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: colors.accent, width: 2),
                        ),
                        child: Icon(
                          Icons.fitness_center_rounded,
                          size: 24.sp,
                          color: colors.accent,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.discoverCoachTitle,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              l10n.discoverCoachSubtitle,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 22.sp,
                        color: colors.accent,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.leading, this.dropdown = false});
  final String label;
  final IconData? leading;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 38.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(17.r),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 18.sp, color: colors.textPrimary),
            SizedBox(width: 6.w),
          ],
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (dropdown) ...[
            SizedBox(width: 4.w),
            Icon(
              Icons.expand_more_rounded,
              size: 18.sp,
              color: colors.textPrimary,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgramCard extends ConsumerWidget {
  const _ProgramCard({required this.l10n, required this.program});
  final AppLocalizations l10n;
  final PremadeProgram program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final words = program
        .name(l10n)
        .split(RegExp(r'[\s/]+'))
        .where((w) => w.isNotEmpty)
        .take(3)
        .toList();

    return GestureDetector(
      onTap: () => showPremadeProgramSheet(
        context,
        program: program,
        onInstalled: (scheduleId) {
          selectInstalledSchedule(ref, scheduleId);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.premadeAdded)));
        },
      ),
      child: Container(
        constraints: BoxConstraints(minHeight: 170.h),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Stacked-words cover block
              Container(
                width: 150.w,
                color: colors.black,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < words.length; i++)
                      Text(
                        words[i].toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i.isEven ? colors.accent : colors.white,
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -1,
                          height: 1.02,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.name(l10n),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: colors.cardElevated,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Text(
                          premadeLevelLabel(l10n, program.level),
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        l10n.discoverRoutinesCount(program.days.length),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13.5.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 10.w),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22.sp,
                  color: colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
