import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_notifier.dart';
import '../../../core/providers/providers.dart';
import '../../../core/security/secure_storage.dart';
import '../../../core/services/exercise_local_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/constants.dart';
import '../../../shared/responsive.dart';
import '../onboarding_state.dart';

/// Screen 6 — Create Account (/onboarding/signup)
/// Name + Email + Password fields. Password strength bar.
/// Apple (iOS) + Google social buttons.
/// Exercise seeding overlay after successful signup.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _seeding = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Password strength ──
  double _passwordStrength(String pw) {
    if (pw.isEmpty) return 0;
    var score = 0.0;
    if (pw.length >= 8) score += 0.25;
    if (pw.contains(RegExp(r'[A-Z]'))) score += 0.25;
    if (pw.contains(RegExp(r'[0-9]'))) score += 0.25;
    if (pw.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score += 0.25;
    return score;
  }

  Color _strengthColor(BuildContext context, double strength) {
    final colors = AppColors.of(context);
    if (strength <= 0.25) return colors.danger;
    if (strength <= 0.5) return colors.amber;
    if (strength <= 0.75) return colors.amber;
    return colors.accent;
  }

  String _strengthLabel(BuildContext context, double strength) {
    final l10n = AppLocalizations.of(context);
    if (strength <= 0.25) return l10n.passwordStrengthWeak;
    if (strength <= 0.75) return l10n.passwordStrengthMedium;
    return l10n.passwordStrengthStrong;
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email.trim());

  bool _isValidPassword(String pw) =>
      pw.length >= 8 &&
      pw.contains(RegExp(r'[A-Z]')) &&
      pw.contains(RegExp(r'[0-9]')) &&
      pw.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    final onboarding = ref.read(onboardingProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);

    await authNotifier.signUp(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      goal: onboarding.goal,
      experience: onboarding.experience,
      gender: onboarding.gender,
    );

    final authState = ref.read(authNotifierProvider);
    if (!mounted) return;

    if (authState.status == AuthStatus.error) {
      final colors = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              authState.errorMessage ?? AppLocalizations.of(context).signUpError),
          backgroundColor: colors.danger,
        ),
      );
      return;
    }

    if (authState.status == AuthStatus.authenticated) {
      await _seedExercisesIfNeeded();
    }
  }

  Future<void> _seedExercisesIfNeeded() async {
    final needsSeed =
        await SecureStorage().read('needs_exercise_seed') == 'true';
    if (!needsSeed) {
      if (mounted) context.go('/onboarding/trial');
      return;
    }

    setState(() => _seeding = true);

    try {
      final db = ref.read(databaseProvider);
      await compute(
        (_) async => ExerciseLocalService.seedFromAssets(db),
        null,
      ).catchError((_) async {
        // Fallback: run on main isolate if compute fails (db can't cross isolates)
        await ExerciseLocalService.seedFromAssets(db);
      });
      await SecureStorage().delete('needs_exercise_seed');
    } catch (e) {
      if (kDebugMode) print('Exercise seeding failed: $e');
      // Still proceed even if seeding fails
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
    final pw = _passwordCtrl.text;
    final strength = _passwordStrength(pw);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Form(
                key: _formKey,
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

                    SizedBox(height: 32.h),

                    // Name field
                    TextFormField(
                      controller: _nameCtrl,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: _inputDecoration(l10n.nameLabel),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? l10n.nameRequired : null,
                      textInputAction: TextInputAction.next,
                    ),

                    SizedBox(height: 16.h),

                    // Email field
                    TextFormField(
                      controller: _emailCtrl,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: _inputDecoration(l10n.emailLabel),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          !_isValidEmail(v ?? '') ? l10n.emailInvalid : null,
                      textInputAction: TextInputAction.next,
                    ),

                    SizedBox(height: 16.h),

                    // Password field
                    TextFormField(
                      controller: _passwordCtrl,
                      style: TextStyle(color: colors.textPrimary),
                      decoration: _inputDecoration(l10n.passwordLabel).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: colors.textSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      obscureText: _obscure,
                      onChanged: (_) => setState(() {}),
                      validator: (v) => !_isValidPassword(v ?? '')
                          ? l10n.passwordRequirements
                          : null,
                    ),

                    SizedBox(height: 8.h),

                    // Password strength bar
                    if (pw.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: strength,
                          backgroundColor: colors.card,
                          valueColor:
                              AlwaysStoppedAnimation(_strengthColor(context, strength)),
                          minHeight: 4.h,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        _strengthLabel(context, strength),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _strengthColor(context, strength),
                        ),
                      ),
                    ],

                    SizedBox(height: 8.h),
                    Text(
                      l10n.passwordRequirements,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: colors.textSecondary,
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Sign Up button
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: colors.background,
                          disabledBackgroundColor: colors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          textStyle: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: 24.sp,
                                height: 24.sp,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.w,
                                  color: colors.textSecondary,
                                ),
                              )
                            : Text(l10n.signUp),
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // Or divider
                    Row(
                      children: [
                        Expanded(
                            child:
                                Divider(color: colors.textSecondary, thickness: 0.5)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Text(l10n.orDivider,
                              style: TextStyle(
                                  color: colors.textSecondary, fontSize: 14.sp)),
                        ),
                        Expanded(
                            child:
                                Divider(color: colors.textSecondary, thickness: 0.5)),
                      ],
                    ),

                    SizedBox(height: 24.h),

                    // Google sign in
                    _socialButton(
                      label: l10n.continueWithGoogle,
                      icon: Icons.g_mobiledata,
                      onTap: () =>
                          ref.read(authNotifierProvider.notifier).signInWithGoogle(),
                    ),

                    SizedBox(height: 12.h),

                    // Apple sign in (iOS only)
                    if (Platform.isIOS)
                      _socialButton(
                        label: l10n.continueWithApple,
                        icon: Icons.apple,
                        onTap: () =>
                            ref.read(authNotifierProvider.notifier).signInWithApple(),
                      ),

                    SizedBox(height: 24.h),

                    // Skip button (dev/testing — bypass auth)
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          await _seedExercisesIfNeeded();
                          if (mounted) context.go('/');
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
            ),

            // Exercise seeding overlay
            if (_seeding)
              Container(
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

  InputDecoration _inputDecoration(String label) {
    final colors = AppColors.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textSecondary),
      filled: true,
      fillColor: colors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: colors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: colors.danger, width: 1.5),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
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
