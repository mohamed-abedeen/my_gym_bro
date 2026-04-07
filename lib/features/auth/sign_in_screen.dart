import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_notifier.dart';
import '../../core/providers/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/constants.dart';
import '../../shared/responsive.dart';

/// Sign In (/auth/signin)
/// Email + Password. Forgot password → resetPasswordForEmail().
/// l10n.noAccount → /onboarding/signup. Apple + Google.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    final authNotifier = ref.read(authNotifierProvider.notifier);
    await authNotifier.signIn(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    final authState = ref.read(authNotifierProvider);
    if (!mounted) return;

    if (authState.status == AuthStatus.error) {
      final colors = AppColors.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              authState.errorMessage ?? AppLocalizations.of(context).signInError),
          backgroundColor: colors.danger,
        ),
      );
      return;
    }

    if (authState.status == AuthStatus.authenticated) {
      context.go('/');
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final success =
        await ref.read(authNotifierProvider.notifier).resetPassword(email);
    if (!mounted) return;
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? l10n.resetPasswordSent : l10n.signInError),
        backgroundColor: success ? colors.success : colors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Form(
            key: _formKey,
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

                SizedBox(height: 32.h),

                // Email field
                TextFormField(
                  controller: _emailCtrl,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp),
                  decoration: _inputDecoration(l10n.emailLabel, colors),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.emailInvalid
                      : null,
                  textInputAction: TextInputAction.next,
                ),

                SizedBox(height: 16.h),

                // Password field
                TextFormField(
                  controller: _passwordCtrl,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp),
                  decoration: _inputDecoration(l10n.passwordLabel, colors).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: colors.textSecondary,
                        size: 24.sp,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) => (v == null || v.isEmpty)
                      ? l10n.passwordLabel
                      : null,
                ),

                SizedBox(height: 12.h),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _handleForgotPassword,
                    child: Text(
                      l10n.forgotPassword,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 32.h),

                // Sign In button
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleSignIn,
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
                            width: 24.w,
                            height: 24.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.w,
                              color: colors.textSecondary,
                            ),
                          )
                        : Text(l10n.signIn),
                  ),
                ),

                SizedBox(height: 24.h),

                // Or divider
                Row(
                  children: [
                    Expanded(
                        child: Divider(
                            color: colors.textSecondary, thickness: 0.5)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(l10n.orDivider,
                          style: TextStyle(
                              color: colors.textSecondary, fontSize: 14.sp)),
                    ),
                    Expanded(
                        child: Divider(
                            color: colors.textSecondary, thickness: 0.5)),
                  ],
                ),

                SizedBox(height: 24.h),

                // Google sign in
                _socialButton(
                  label: l10n.continueWithGoogle,
                  icon: Icons.g_mobiledata,
                  onTap: () =>
                      ref.read(authNotifierProvider.notifier).signInWithGoogle(),
                  colors: colors,
                ),

                SizedBox(height: 12.h),

                // Apple sign in (iOS only)
                if (Platform.isIOS)
                  _socialButton(
                    label: l10n.continueWithApple,
                    icon: Icons.apple,
                    onTap: () =>
                        ref.read(authNotifierProvider.notifier).signInWithApple(),
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
      ),
    );
  }

  InputDecoration _inputDecoration(String label, AppColorsTheme colors) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
        filled: true,
        fillColor: colors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: colors.accent, width: 1.5.w),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: colors.danger, width: 1.w),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: colors.danger, width: 1.5.w),
        ),
      );

  Widget _socialButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
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
