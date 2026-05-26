import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Figma frames 49/53/54 — Target zones selection.
/// "What are your target zones?"
/// Anatomy figure in center with 6 selectable buttons:
/// Arms, Abs, Pecs, Back, Legs, All.
/// Selected zones get accent border highlight.
class TargetZonesScreen extends ConsumerWidget {
  const TargetZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final onboarding = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final selected = onboarding.targetZones;
    const progress = 8 / 9;

    final zones = [
      ('arms', l10n.arms),
      ('abs', l10n.abs),
      ('pecs', l10n.pecs),
      ('back', l10n.targetBack),
      ('legs', l10n.legs),
      ('all', l10n.all),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 12.h),

            // ── Back arrow + Progress bar ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.chevron_left,
                        color: colors.textPrimary, size: 28.sp),
                  ),
                  SizedBox(width: 8.w),
                  const Expanded(child: _ProgressBar(progress: progress)),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // ── Title ──
            Text(
              l10n.targetZonesTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.2,
              ),
            ),

            SizedBox(height: 24.h),

            // ── Body figure + zone buttons ──
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Anatomy silhouette placeholder
                  Icon(
                    Icons.accessibility_new_rounded,
                    size: 280.sp,
                    color: AppColors.of(context).avatarPlaceholderDark,
                  ),

                  // Zone buttons — positioned around the figure
                  // Left column: Arms, Pecs, Legs
                  Positioned(
                    left: 24.w,
                    top: 40.h,
                    child: _ZoneChip(
                      label: zones[0].$2,
                      isSelected: selected.contains(zones[0].$1),
                      onTap: () => notifier.toggleTargetZone(zones[0].$1),
                    ),
                  ),
                  Positioned(
                    left: 24.w,
                    top: 120.h,
                    child: _ZoneChip(
                      label: zones[2].$2,
                      isSelected: selected.contains(zones[2].$1),
                      onTap: () => notifier.toggleTargetZone(zones[2].$1),
                    ),
                  ),
                  Positioned(
                    left: 24.w,
                    bottom: 80.h,
                    child: _ZoneChip(
                      label: zones[4].$2,
                      isSelected: selected.contains(zones[4].$1),
                      onTap: () => notifier.toggleTargetZone(zones[4].$1),
                    ),
                  ),

                  // Right column: Abs, Back, All
                  Positioned(
                    right: 24.w,
                    top: 40.h,
                    child: _ZoneChip(
                      label: zones[1].$2,
                      isSelected: selected.contains(zones[1].$1),
                      onTap: () => notifier.toggleTargetZone(zones[1].$1),
                    ),
                  ),
                  Positioned(
                    right: 24.w,
                    top: 120.h,
                    child: _ZoneChip(
                      label: zones[3].$2,
                      isSelected: selected.contains(zones[3].$1),
                      onTap: () => notifier.toggleTargetZone(zones[3].$1),
                    ),
                  ),
                  Positioned(
                    right: 24.w,
                    bottom: 80.h,
                    child: _ZoneChip(
                      label: zones[5].$2,
                      isSelected: selected.contains(zones[5].$1) ||
                          selected.contains('all'),
                      onTap: () => notifier.toggleTargetZone(zones[5].$1),
                    ),
                  ),
                ],
              ),
            ),

            // ── Continue button ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: selected.isNotEmpty
                      ? () => context.go('/onboarding/notification-tone')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.background,
                    disabledBackgroundColor: colors.card,
                    disabledForegroundColor: colors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    textStyle: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l10n.continueButton),
                ),
              ),
            ),

            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {

  const _ZoneChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.15)
              : AppColors.of(context).avatarPlaceholderDark,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? colors.accent : AppColors.of(context).avatarPlaceholder,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color:
                isSelected ? colors.accent : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 6.h,
      decoration: BoxDecoration(
        color: AppColors.of(context).avatarPlaceholderDark,
        borderRadius: BorderRadius.circular(3.r),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colors.accent, const Color(0xFF12FF00)],
            ),
            borderRadius: BorderRadius.circular(3.r),
          ),
        ),
      ),
    );
  }
}
