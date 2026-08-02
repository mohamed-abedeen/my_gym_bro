import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:my_gym_bro/core/auth/auth_notifier.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Sign In (/auth/signin)
/// OAuth-only: Google (all platforms) + Apple (iOS). No email/password.
/// l10n.noAccount → /onboarding/signup.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  // OAuth completes out-of-band (deep-link → onAuthStateChange), not via the
  // button's future — so navigation must react to the state transition.
  bool _oauthInFlight = false;

  void _startOAuth(Future<void> Function() flow) {
    setState(() => _oauthInFlight = true);
    flow();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen<AppAuthState>(authNotifierProvider, (previous, next) {
      if (!_oauthInFlight) return;
      if (next.status == AuthStatus.authenticated) {
        _oauthInFlight = false;
        context.go('/');
      } else if (next.status == AuthStatus.error) {
        _oauthInFlight = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ??
                AppLocalizations.of(context).signInError),
            backgroundColor: AppColors.of(context).danger,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60.h),

              Text(
                l10n.signIn,
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
                colors: colors,
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
                  colors: colors,
                ),

              SizedBox(height: 32.h),

              // No account link
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/onboarding/signup'),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          fontSize: 14.sp, color: colors.textSecondary),
                      children: [
                        TextSpan(text: '${l10n.noAccount} '),
                        TextSpan(
                          text: l10n.signUp,
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required AppColorsTheme colors,
  }) =>
      SizedBox(
        width: double.infinity,
        height: 52.h,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 24.sp),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.textSecondary, width: 0.5.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            textStyle: TextStyle(fontSize: 15.sp),
          ),
        ),
      );
}
