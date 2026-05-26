import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Figma frames 33-37 — Goal selection.
/// "What's your main goal for training?"
/// 4 cards: Bulking / Strength / Cutting / Maintaining.
/// Each card has a yellow icon, title, and subtitle.
/// Selected card gets accent border. Progress bar at top.
class GoalScreen extends ConsumerWidget {
  const GoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final onboarding = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final selected = onboarding.goal;

    // Progress: goal is step 3 of ~8
    const progress = 3 / 8;

    final goals = <_GoalOption>[
      _GoalOption(
        key: 'bulking',
        title: l10n.bulking,
        subtitle: l10n.bulkingDesc,
        icon: Icons.trending_up_rounded,
      ),
      _GoalOption(
        key: 'strength',
        title: l10n.strength,
        subtitle: l10n.strengthDesc,
        icon: Icons.fitness_center_rounded,
      ),
      _GoalOption(
        key: 'cutting',
        title: l10n.cutting,
        subtitle: l10n.cuttingDesc,
        icon: Icons.content_cut_rounded,
      ),
      _GoalOption(
        key: 'maintaining',
        title: l10n.maintaining,
        subtitle: l10n.maintainingDesc,
        icon: Icons.people_rounded,
      ),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 12.h),

              // ── Back arrow + Progress bar ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(Icons.chevron_left,
                        color: colors.textPrimary, size: 28.sp),
                  ),
                  SizedBox(width: 8.w),
                  const Expanded(
                    child: _ProgressBar(progress: progress),
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              // ── Title ──
              Text(
                l10n.goalTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.2,
                ),
              ),

              SizedBox(height: 32.h),

              // ── Goal cards ──
              ...goals.map((g) {
                final isSelected = selected == g.key;
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: GestureDetector(
                    onTap: () => notifier.setGoal(g.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 18.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accent.withValues(alpha: 0.15)
                            : colors.card,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isSelected
                              ? colors.accent
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Yellow icon
                          Icon(g.icon,
                              color: colors.accent, size: 36.sp),
                          SizedBox(width: 14.w),
                          // Title + subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.title,
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  g.subtitle,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const Spacer(),

              // ── Privacy text ──
              Text(
                l10n.dataPrivate,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: colors.textSecondary,
                ),
              ),

              SizedBox(height: 12.h),

              // ── Continue button ──
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: selected != null
                      ? () => context.go('/onboarding/experience')
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

              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalOption {

  const _GoalOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;
}

/// Green-to-dark progress bar matching Figma onboarding.
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
