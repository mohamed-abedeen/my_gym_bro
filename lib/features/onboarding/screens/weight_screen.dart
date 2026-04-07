import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/constants.dart';
import '../../../shared/responsive.dart';
import '../onboarding_state.dart';

/// Figma frames 41-42 — Weight picker.
/// Scroll wheel for whole kg + decimal, kgs/lbs toggle pill.
class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  late FixedExtentScrollController _wholeController;
  late FixedExtentScrollController _decimalController;
  bool _isMetric = true;
  int _whole = 72;
  int _decimal = 0;

  @override
  void initState() {
    super.initState();
    _wholeController = FixedExtentScrollController(initialItem: _whole - 30);
    _decimalController = FixedExtentScrollController(initialItem: _decimal);
    _updateWeight();
  }

  @override
  void dispose() {
    _wholeController.dispose();
    _decimalController.dispose();
    super.dispose();
  }

  void _updateWeight() {
    final value = _whole + _decimal * 0.1;
    final kg = _isMetric ? value : value * 0.453592;
    ref.read(onboardingProvider.notifier).setWeight(kg);
    ref.read(onboardingProvider.notifier).setUseMetric(_isMetric);
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    const progress = 6 / 8;
    final unit = _isMetric ? 'kg' : 'lbs';

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
                  Expanded(child: _ProgressBar(progress: progress)),
                ],
              ),
            ),

            SizedBox(height: 32.h),

            // ── Title ──
            Text(
              l10n.weightTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),

            const Spacer(),

            // ── Scroll wheels ──
            SizedBox(
              height: 200.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Whole number wheel
                  SizedBox(
                    width: 100.w,
                    child: ListWheelScrollView.useDelegate(
                      controller: _wholeController,
                      itemExtent: 44.h,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) {
                        setState(() => _whole = i + 30);
                        _updateWeight();
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, i) {
                          final value = i + 30;
                          if (value < 30 || value > 250) return null;
                          final isSelected = value == _whole;
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
                                          horizontal: 16.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: colors.textSecondary,
                                            width: 1),
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                      ),
                                      child: Text('$value'),
                                    )
                                  : Text('$value'),
                            ),
                          );
                        },
                        childCount: 221,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Decimal wheel
                  SizedBox(
                    width: 100.w,
                    child: ListWheelScrollView.useDelegate(
                      controller: _decimalController,
                      itemExtent: 44.h,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) {
                        setState(() => _decimal = i);
                        _updateWeight();
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        builder: (context, i) {
                          if (i < 0 || i > 9) return null;
                          final isSelected = i == _decimal;
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
                                          horizontal: 16.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: colors.textSecondary,
                                            width: 1),
                                        borderRadius:
                                            BorderRadius.circular(8.r),
                                      ),
                                      child: Text('.$i $unit'),
                                    )
                                  : Text('.$i $unit'),
                            ),
                          );
                        },
                        childCount: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Unit toggle pill ──
            _UnitToggle(
              leftLabel: l10n.kgs,
              rightLabel: l10n.lbs,
              isLeftSelected: _isMetric,
              onToggle: (isLeft) {
                setState(() => _isMetric = isLeft);
                _updateWeight();
              },
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
                  onPressed: () => context.go('/onboarding/height'),
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
  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final ValueChanged<bool> onToggle;

  const _UnitToggle({
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Container(
        width: 220.w,
        height: 52.h,
        decoration: BoxDecoration(
          color: Colors.grey[850] ?? Colors.grey[800],
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
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 6.h,
      decoration: BoxDecoration(
        color: Colors.grey[800],
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
