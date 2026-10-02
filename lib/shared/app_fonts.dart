import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Font styles for the app.
///
/// Primary: system font (SF Pro on iOS, Roboto on Android) — used for all text.
/// Secondary: Familjen Grotesk (bundled, OFL) — used ONLY for trend indicator
/// values.
class AppFonts {
  AppFonts._();

  /// Trend indicator — Familjen Grotesk 10px 400.
  /// Color: trendPositive (#49995C) or trendNegative (#FF0004).
  static TextStyle trend(Color color) => TextStyle(
        fontFamily: 'FamiljenGrotesk',
        fontSize: 10.sp,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle trendPositive(BuildContext context) =>
      trend(AppColors.of(context).trendPositive);
  static TextStyle trendNegative(BuildContext context) =>
      trend(AppColors.of(context).trendNegative);
}
