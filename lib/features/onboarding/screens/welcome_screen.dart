import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants.dart';
import '../../../shared/responsive.dart';

/// Screen 2 — Welcome (/onboarding/welcome)
/// l10n.startTrial → /onboarding/goal
/// l10n.alreadyAccount text link → /auth/signin
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // App name
              Text(
                'My Gym Bro',
                style: TextStyle(
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),

              SizedBox(height: 16.h),

              // Subtitle
              Text(
                'Built by Gym Bros, For Gym Bros',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.sp,
                  color: colors.textSecondary,
                ),
              ),

              const Spacer(flex: 3),

              // Start Trial button
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding/gender'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    textStyle: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
              ),

              SizedBox(height: 20.h),

              // Already have an account link
              GestureDetector(
                onTap: () => context.go('/auth/signin'),
                child: Text(
                  l10n.alreadyAccount,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: colors.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.accent,
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              // Skip to app (dev/testing)
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(
                  l10n.skip,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14.sp,
                  ),
                ),
              ),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
