import 'package:flutter/material.dart';

import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/liquid_glass_button.dart';

/// A tappable text field that opens a numpad bottom sheet for input.
class InlineEditableField extends StatelessWidget {

  const InlineEditableField({
    required this.value,
    required this.onChanged,
    this.suffix,
    this.allowDecimal = true,
    super.key,
  });
  final String value;
  final String? suffix;
  final ValueChanged<String> onChanged;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () => _showNumpad(context),
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 44.w, minHeight: 44.h),
        child: Center(
          widthFactor: 1,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            child: Text(
              suffix != null ? '$value $suffix' : value,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature('ss15')],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showNumpad(BuildContext context) {
    var current = value;
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        var isFirstTap = true;
        return StatefulBuilder(
          builder: (ctx, setState) {
            final displayText = suffix != null ? '$current $suffix' : current;
            return Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Display
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        vertical: 16.h, horizontal: 20.w),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Center(
                      child: isFirstTap
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                displayText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 32.sp,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [FontFeature('ss15')],
                                ),
                              ),
                            )
                          : Text(
                              displayText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 32.sp,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [FontFeature('ss15')],
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Numpad grid
                  _NumpadGrid(
                    allowDecimal: allowDecimal,
                    onDigit: (d) => setState(() {
                      if (isFirstTap) {
                        current = d;
                        isFirstTap = false;
                      } else if (current == '0') {
                        current = d;
                      } else {
                        current += d;
                      }
                    }),
                    onDecimal: () => setState(() {
                      if (isFirstTap) {
                        current = '0.';
                        isFirstTap = false;
                      } else if (!current.contains('.')) {
                        current += '.';
                      }
                    }),
                    onBackspace: () => setState(() {
                      if (isFirstTap) {
                        current = '0';
                        isFirstTap = false;
                      } else {
                        if (current.isNotEmpty) {
                          current = current.substring(0, current.length - 1);
                        }
                        if (current.isEmpty) current = '0';
                      }
                    }),
                  ),
                  SizedBox(height: 12.h),
                  // Done button
                  SizedBox(
                    width: double.infinity,
                    child: LiquidGlassButton(
                      width: double.infinity,
                      height: 48.h,
                      opacity: 0.25,
                      onTap: () {
                        onChanged(current);
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        l10n.done,
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NumpadGrid extends StatelessWidget {

  const _NumpadGrid({
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    required this.allowDecimal,
  });
  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [if (allowDecimal) '.' else '', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) {
                return SizedBox(width: 72.w, height: 48.h);
              }
              return GestureDetector(
                onTap: () {
                  if (key == '⌫') {
                    onBackspace();
                  } else if (key == '.') {
                    onDecimal();
                  } else {
                    onDigit(key);
                  }
                },
                child: Container(
                  width: 72.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Center(
                    child: key == '⌫'
                        ? Icon(Icons.backspace_outlined,
                            color: colors.textPrimary, size: 22.sp)
                        : Text(
                            key,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
