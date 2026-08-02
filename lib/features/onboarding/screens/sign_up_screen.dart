import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/auth/auth_notifier.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/core/security/secure_storage.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/core/services/program_seeder.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Screen 6 — Create Account (/onboarding/signup)
/// OAuth-only: Google (all platforms) + Apple (iOS). No email/password.
/// Exercise seeding overlay after successful signup.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  bool _seeding = false;
  // OAuth completes out-of-band (deep-link → onAuthStateChange), not via the
  // button's future — navigation and onboarding-data merge must react to the
  // state transition. Armed only while a social flow is in flight.
  bool _oauthInFlight = false;

  void _startOAuth(Future<void> Function() flow) {
    setState(() => _oauthInFlight = true);
    flow();
  }

  /// Finish a Google/Apple sign-up: layer the onboarding answers onto the
  /// profile row the auth listener bootstrapped, then seed + continue.
  Future<void> _completeOAuthSignUp() async {
    final onboarding = ref.read(onboardingProvider);
    try {
      final dao = UserProfileDao(ref.read(databaseProvider));
      await dao.mergeIntoFirst(UserProfilesCompanion(
        goal: Value.absentIfNull(onboarding.goal),
        experience: Value.absentIfNull(onboarding.experience),
        gender: Value.absentIfNull(onboarding.gender),
        bodyWeightKg: Value.absentIfNull(onboarding.weightKg),
        heightCm: Value.absentIfNull(onboarding.heightCm),
        notificationTone: Value(onboarding.notificationTone.wireValue),
      ));
    } on Exception {
      // Non-fatal — these fields can all be edited later in Settings.
    }
    await _seedExercisesIfNeeded();
  }

  Future<void> _seedExercisesIfNeeded() async {
    // Exercises are no longer bundled/seeded in bulk — they sync from the
    // exercise API and are cached on demand. We only ensure the tiny bundled
    // starter set is cached so the default program has rich offline data.
    await SecureStorage().delete('needs_exercise_seed');

    setState(() => _seeding = true);

    try {
      final db = ref.read(databaseProvider);
      final repo = ref.read(exerciseRepositoryProvider);
      await ProgramSeeder(db, repo).ensureStarterCached();
    } on Exception {
      // Non-fatal — proceed regardless.
    }

    if (mounted) {
      setState(() => _seeding = false);
      context.go('/onboarding/trial');
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading || _seeding;

    ref.listen<AppAuthState>(authNotifierProvider, (previous, next) {
      if (!_oauthInFlight) return;
      if (next.status == AuthStatus.authenticated) {
        _oauthInFlight = false;
        _completeOAuthSignUp();
      } else if (next.status == AuthStatus.error) {
        _oauthInFlight = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ??
                AppLocalizations.of(context).signUpError),
            backgroundColor: AppColors.of(context).danger,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 60.h),

                  Text(
                    l10n.signUp,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),

                  SizedBox(height: 48.h),

                  // Google sign in
                  _socialButton(
                    label: l10n.continueWithGoogle,
                    icon: Icons.g_mobiledata,
                    onTap: isLoading
                        ? null
                        : () => _startOAuth(ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle),
                  ),

                  SizedBox(height: 12.h),

                  // Apple sign in (iOS only)
                  if (Platform.isIOS)
                    _socialButton(
                      label: l10n.continueWithApple,
                      icon: Icons.apple,
                      onTap: isLoading
                          ? null
                          : () => _startOAuth(ref
                              .read(authNotifierProvider.notifier)
                              .signInWithApple),
                    ),

                  SizedBox(height: 24.h),

                  // Skip button (dev/testing — bypass auth)
                  Center(
                    child: TextButton(
                      onPressed: () async {
                        final router = GoRouter.of(context);
                        await _seedExercisesIfNeeded();
                        if (!mounted) return;
                        router.go('/');
                      },
                      child: Text(
                        l10n.skip,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14.sp,
                          decoration: TextDecoration.underline,
                          decorationColor: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 40.h),
                ],
              ),
            ),

            // Exercise seeding overlay
            if (_seeding)
              ColoredBox(
                color: colors.background.withValues(alpha: 0.9),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: colors.accent),
                      SizedBox(height: 24.h),
                      Text(
                        l10n.loadingExercises,
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 24.sp),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.textSecondary, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          textStyle: TextStyle(fontSize: 15.sp),
        ),
      ),
    );
  }
}
