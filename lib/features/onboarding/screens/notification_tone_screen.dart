import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/core/services/notification_tone.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Onboarding step: "Pick your voice" — lets the user choose the
/// motivational tone they'll hear in all notifications.
class NotificationToneScreen extends ConsumerWidget {
  const NotificationToneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final onboarding = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final selected = onboarding.notificationTone;
    const progress = 9 / 9;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 16.h),

            // ── Progress bar ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4.h,
                  color: colors.accent,
                  backgroundColor: colors.card,
                ),
              ),
            ),

            SizedBox(height: 32.h),

            // ── Title ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                l10n.notificationToneOnboardingTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            SizedBox(height: 8.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                l10n.notificationToneOnboardingSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.subtitleText,
                  fontSize: 14.sp,
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // ── Tone cards ──
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                children: NotificationTone.values.map((tone) {
                  final isSelected = tone == selected;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: _OnboardingToneCard(
                      tone: tone,
                      isSelected: isSelected,
                      colors: colors,
                      l10n: l10n,
                      onTap: () => notifier.setNotificationTone(tone),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Continue button ──
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
              child: SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding/signup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l10n.continueButton),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingToneCard extends StatelessWidget {

  const _OnboardingToneCard({
    required this.tone,
    required this.isSelected,
    required this.colors,
    required this.l10n,
    required this.onTap,
  });
  final NotificationTone tone;
  final bool isSelected;
  final AppColorsTheme colors;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected
                ? colors.accent
                : colors.textSecondary.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    toneLabel(tone, l10n),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: colors.accent, size: 18.sp),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              toneDescription(tone, l10n),
              style: TextStyle(
                color: colors.subtitleText,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.notificationToneExampleLabel.toUpperCase(),
                    style: TextStyle(
                      color: colors.subtitleText,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    toneExampleSentence(tone),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13.sp,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
