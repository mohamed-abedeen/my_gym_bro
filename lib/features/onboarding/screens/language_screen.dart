import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/database/daos/user_profile_dao.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Screen 5 — Language (/onboarding/language)
/// 4 language cards with flags. Tap → update localeProvider IMMEDIATELY + save to Drift.
/// l10n.skip → use system language.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final selectedLocale = ref.watch(localeProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    final languages = [
      ('en', '\u{1F1EC}\u{1F1E7}', 'English'),
      ('fr', '\u{1F1EB}\u{1F1F7}', 'Fran\u{00E7}ais'),
      ('de', '\u{1F1E9}\u{1F1EA}', 'Deutsch'),
      ('es', '\u{1F1EA}\u{1F1F8}', 'Espa\u{00F1}ol'),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60.h),

              Text(
                l10n.chooseLanguage,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),

              SizedBox(height: 32.h),

              ...languages.map((lang) {
                final isSelected =
                    selectedLocale?.languageCode == lang.$1;
                return Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: GestureDetector(
                    onTap: () => _selectLanguage(
                        context, ref, notifier, lang.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color:
                              isSelected ? colors.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(lang.$2, style: TextStyle(fontSize: 28.sp)),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Text(
                              lang.$3,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle,
                                color: colors.accent, size: 24.sp),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding/signup'),
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
                  child: Text(l10n.continueButton),
                ),
              ),

              SizedBox(height: 12.h),

              // Skip — use system language
              Center(
                child: GestureDetector(
                  onTap: () {
                    ref.read(localeProvider.notifier).state = null;
                    notifier.setLanguage('system');
                    _persistLanguage(ref, 'system');
                    context.go('/onboarding/signup');
                  },
                  child: Text(
                    l10n.skip,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: colors.textSecondary,
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
    );
  }

  void _selectLanguage(BuildContext context, WidgetRef ref,
      OnboardingNotifier notifier, String langCode) {
    // Live switch locale
    ref.read(localeProvider.notifier).state = Locale(langCode);
    notifier.setLanguage(langCode);
    _persistLanguage(ref, langCode);
  }

  /// Save language preference to Drift (best-effort, profile may not exist yet).
  Future<void> _persistLanguage(WidgetRef ref, String langCode) async {
    try {
      final db = ref.read(databaseProvider);
      final dao = UserProfileDao(db);
      final profile = await dao.getFirst();
      if (profile != null) {
        await dao.updateLanguage(profile.localId, langCode);
      }
    } on Exception {
      // Profile may not exist yet during onboarding — that's fine.
    }
  }
}
