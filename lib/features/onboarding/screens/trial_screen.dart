import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants.dart';
import '../../../shared/responsive.dart';

/// Screen 7 — Trial Confirmation (/onboarding/trial)
/// l10n.trialStarted. 4 feature rows. l10n.letsGo → /home.
class TrialScreen extends StatelessWidget {
  const TrialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    final features = [
      (Icons.fitness_center, l10n.trialFeature1),
      (Icons.library_books, l10n.trialFeature2),
      (Icons.calendar_month, l10n.trialFeature3),
      (Icons.insights, l10n.trialFeature4),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Checkmark
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent,
                ),
                child: Icon(
                  Icons.check,
                  size: 40.sp,
                  color: colors.background,
                ),
              ),

              SizedBox(height: 32.h),

              Text(
                l10n.trialStarted,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),

              SizedBox(height: 40.h),

              // Feature rows
              ...features.map((f) => Padding(
                    padding: EdgeInsets.only(bottom: 20.h),
                    child: Row(
                      children: [
                        Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(f.$1,
                              color: colors.accent, size: 22.sp),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Text(
                            f.$2,
                            style: TextStyle(
                              fontSize: 16.sp,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),

              const Spacer(flex: 3),

              // Let's Go button
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    textStyle: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l10n.letsGo),
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
