import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_gym_bro/features/onboarding/onboarding_state.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Figma frames 43-44 — Height picker.
/// Single scroll wheel for cm (or ft), cm/ft toggle pill.
class HeightScreen extends ConsumerStatefulWidget {
  const HeightScreen({super.key});

  @override
  ConsumerState<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends ConsumerState<HeightScreen> {
  late FixedExtentScrollController _controller;
  bool _isMetric = true;
  int _selectedCm = 170;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _selectedCm - 100);
    _updateHeight();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateHeight() {
    ref.read(onboardingProvider.notifier).setHeight(_selectedCm.toDouble());
  }

  String _formatValue(int cm) {
    if (_isMetric) return '$cm cm';
    // Convert to feet/inches display
    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return "$feet'$inches\"";
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    const progress = 7 / 8;

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

            SizedBox(height: 32.h),

            // ── Title ──
            Text(
              l10n.heightTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),

            const Spacer(),

            // ── Scroll wheel ──
            SizedBox(
              height: 220.h,
              child: ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: 44.h,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  setState(() => _selectedCm = i + 100);
                  _updateHeight();
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, i) {
                    final cm = i + 100;
                    if (cm < 100 || cm > 250) return null;
                    final isSelected = cm == _selectedCm;
                    final text = _formatValue(cm);
                    return Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontSize: isSelected ? 28.sp : 20.sp,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                        child: isSelected
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: colors.textSecondary),
                                  borderRadius:
                                      BorderRadius.circular(8.r),
                                ),
                                child: Text(text),
                              )
                            : Text(text),
                      ),
                    );
                  },
                  childCount: 151,
                ),
              ),
            ),

            const Spacer(),

            // ── Unit toggle pill ──
            _UnitToggle(
              leftLabel: l10n.cm,
              rightLabel: l10n.ft,
              isLeftSelected: _isMetric,
              onToggle: (isLeft) => setState(() => _isMetric = isLeft),
            ),

            SizedBox(height: 32.h),

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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding/target-zones'),
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

class _UnitToggle extends StatelessWidget {

  const _UnitToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onToggle,
  });
  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Container(
        width: 220.w,
        height: 52.h,
        decoration: BoxDecoration(
          color: AppColors.of(context).avatarPlaceholderDark,
          borderRadius: BorderRadius.circular(26.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isLeftSelected
                        ? colors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    leftLabel,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: isLeftSelected
                          ? colors.background
                          : colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: !isLeftSelected
                        ? colors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    rightLabel,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: !isLeftSelected
                          ? colors.background
                          : colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
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
