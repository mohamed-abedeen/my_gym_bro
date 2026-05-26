import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Figma frames 45-46 — Experience level selection.
/// Dark background with gym-photo feel.
/// "How much training experience do you have ?"
/// Swipeable pages: Base (0-1y) / Mid (1-3y) / Pro (3+y).
/// Large centered text with years below. Page dots.
class ExperienceScreen extends ConsumerStatefulWidget {
  const ExperienceScreen({super.key});

  @override
  ConsumerState<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends ConsumerState<ExperienceScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  static const _levels = [
    ('base', 'Base', '0-1 years'),
    ('mid', 'Mid', '1-3 years'),
    ('pro', 'Pro', '3+ years'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Default to first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingProvider.notifier).setExperience(_levels[0].$1);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    const progress = 4 / 8;

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

            SizedBox(height: 16.h),

            // ── Title ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                l10n.experienceTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),

            // ── Swipeable level pages ──
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _levels.length,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  ref
                      .read(onboardingProvider.notifier)
                      .setExperience(_levels[i].$1);
                },
                itemBuilder: (context, i) {
                  final level = _levels[i];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Large level name
                      Text(
                        level.$2,
                        style: TextStyle(
                          fontSize: 72.sp,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      // Year range
                      Text(
                        level.$3,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Page dots ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _levels.length,
                (i) => Container(
                  width: i == _currentPage ? 24.w : 8.w,
                  height: 8.h,
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? colors.accent
                        : AppColors.of(context).avatarPlaceholder,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // ── Continue button ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding/birthday'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.background,
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
