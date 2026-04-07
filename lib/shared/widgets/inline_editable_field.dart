import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../constants.dart';
import '../responsive.dart';
import 'liquid_glass_button.dart';

/// A tappable text field that opens a numpad bottom sheet for input.
class InlineEditableField extends StatelessWidget {
  final String value;
  final String? suffix;
  final ValueChanged<String> onChanged;
  final bool allowDecimal;

  const InlineEditableField({
    required this.value,
    required this.onChanged,
    this.suffix,
    this.allowDecimal = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () => _showNumpad(context),
      child: Text(
        suffix != null ? '$value $suffix' : value,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature('ss15')],
        ),
      ),
    );
  }

  void _showNumpad(BuildContext context) {
    String current = value;
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
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
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Text(
                      suffix != null ? '$current $suffix' : current,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature('ss15')],
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Numpad grid
                  _NumpadGrid(
                    allowDecimal: allowDecimal,
                    onDigit: (d) => setState(() {
                      if (current == '0') {
                        current = d;
                      } else {
                        current += d;
                      }
                    }),
                    onDecimal: () => setState(() {
                      if (!current.contains('.')) current += '.';
                    }),
                    onBackspace: () => setState(() {
                      if (current.isNotEmpty) {
                        current = current.substring(0, current.length - 1);
                      }
                      if (current.isEmpty) current = '0';
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
  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;
  final bool allowDecimal;

  const _NumpadGrid({
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
    required this.allowDecimal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [allowDecimal ? '.' : '', '0', '⌫'],
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
                    color: Colors.white.withValues(alpha: 0.1),
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
