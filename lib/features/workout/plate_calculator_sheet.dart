import 'package:flutter/material.dart';
import 'package:my_gym_bro/core/services/units.dart';
import 'package:my_gym_bro/features/workout/plate_calculator.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/inline_editable_field.dart';

/// Shows the plate calculator as a small frosted bottom sheet
/// (same GlassSurface recipe as the active-session rest sheet).
void showPlateCalculatorSheet(
  BuildContext context, {
  required WeightUnit unit,
  double initialWeight = 0,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlateCalculatorSheet(
      unit: unit,
      initialWeight: initialWeight,
    ),
  );
}

class _PlateCalculatorSheet extends StatefulWidget {
  const _PlateCalculatorSheet({
    required this.unit,
    required this.initialWeight,
  });

  final WeightUnit unit;

  /// Target weight in [unit] (display unit, not canonical kg).
  final double initialWeight;

  @override
  State<_PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<_PlateCalculatorSheet> {
  late double _target = widget.initialWeight;
  late double _bar =
      widget.unit == WeightUnit.lbs ? kDefaultBarLbs : kDefaultBarKg;

  bool get _isLbs => widget.unit == WeightUnit.lbs;
  List<double> get _barPresets => _isLbs ? const [45.0, 35.0] : const [20.0, 15.0];

  /// Values are already in the display unit — no kg conversion here.
  /// Rounds to 2 decimals and strips trailing zeros so unit-converted
  /// weights don't leak binary-float noise (10 lbs -> 9.999999999999998).
  String _fmt(double v) =>
      v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final unitLabel = weightUnitLabel(widget.unit);

    final load = calculatePlates(
      targetWeight: _target,
      barWeight: _bar,
      plates: _isLbs ? kLbsPlates : kKgPlates,
    );
    final platesText = load.platesPerSide.isEmpty
        ? '—'
        : load.platesPerSide
            .map((p) => '${_fmt(p.plate)} × ${p.count}')
            .join(' · ');

    return Padding(
      padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 12.h),
      child: SafeArea(
        top: false,
        child: GlassSurface(
          radius: 32.r,
          tint: colors.panelBackground.withValues(alpha: 0.78),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 38.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                l10n.plateCalculator,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16.h),

              // Target weight (tap opens the shared numpad sheet)
              Row(
                children: [
                  Text(
                    l10n.plateCalcTargetWeight,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  InlineEditableField(
                    value: _fmt(_target),
                    suffix: unitLabel,
                    onChanged: (v) => setState(
                      () => _target = double.tryParse(v) ?? _target,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),

              // Bar weight presets
              Row(
                children: [
                  Text(
                    l10n.plateCalcBar,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  for (final preset in _barPresets) ...[
                    _barChip(colors, preset, unitLabel),
                    SizedBox(width: 8.w),
                  ],
                ],
              ),
              SizedBox(height: 20.h),

              // Result: plates per side
              Text(
                platesText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                l10n.plateCalcPerSide,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (load.remainder != 0) ...[
                SizedBox(height: 10.h),
                Text(
                  l10n.plateCalcUnreachable(
                    '${_fmt(load.remainder.abs())} $unitLabel',
                  ),
                  style: TextStyle(
                    color: colors.amber,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _barChip(AppColorsTheme colors, double preset, String unitLabel) {
    final selected = _bar == preset;
    // button + selected traits; the visible text supplies the label.
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () => setState(() => _bar = preset),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100.r),
          ),
          child: Text(
            '${_fmt(preset)} $unitLabel',
            style: TextStyle(
              color: selected ? colors.accent : colors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
