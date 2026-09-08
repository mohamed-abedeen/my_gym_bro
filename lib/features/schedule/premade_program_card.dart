import 'package:flutter/material.dart';
import 'package:my_gym_bro/features/schedule/premade_programs.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/dashed_border.dart';

/// Shared premade-program card — black cover block with the program's own
/// icon and category, plus name / level pill / routines meta on the right.
/// Used by the Discover screen and the full premade library.
class PremadeProgramCard extends StatelessWidget {
  const PremadeProgramCard({
    required this.program,
    required this.l10n,
    required this.onTap,
    super.key,
  });

  final PremadeProgram program;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
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
              // Icon + category cover block — uses the program's own icon
              Container(
                width: 150.w,
                color: colors.black,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(program.icon, size: 44.sp, color: colors.accent),
                    SizedBox(height: 10.h),
                    Text(
                      premadeCategoryLabel(l10n, program.category)
                          .toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
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
                        '${l10n.discoverRoutinesCount(program.days.length)}'
                        ' · ${l10n.premadeMinutes(program.minutes)}',
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

/// "Create your own" card for the Discover screen — mirrors
/// [PremadeProgramCard]'s shell (same [AppRadius.card] radius and 150-wide
/// cover) but with a dashed [AppColorsTheme.separator] outline and an accent
/// cover, and routes to the schedule builder instead of a program sheet.
class CreateOwnProgramCard extends StatelessWidget {
  const CreateOwnProgramCard({
    required this.l10n,
    required this.onTap,
    super.key,
  });

  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        // Foreground so the dashes sit on top of the clipped accent cover.
        foregroundPainter: DashedBorderPainter(
          color: colors.separator,
          radius: AppRadius.card.r,
          strokeWidth: 1.5,
        ),
        child: Container(
          constraints: BoxConstraints(minHeight: 120.h),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Accent cover with the "add" glyph — the create affordance.
                Container(
                  width: 150.w,
                  color: colors.accent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 44.sp,
                        color: colors.todayPillText,
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        l10n.discoverCreateOwnTag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.todayPillText,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
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
                          l10n.discoverCreateOwn,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 17.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          l10n.discoverCreateOwnSub,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13.5.sp,
                            height: 1.4,
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
      ),
    );
  }
}
