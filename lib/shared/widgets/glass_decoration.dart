import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/responsive.dart';

/// Shared visual language for the app's frosted-glass surfaces.
///
/// Three sibling widgets used to inline-duplicate this shadow + tint math:
///
///   * `GlassCard` (non-interactive containers — session log rows, etc.)
///   * `LiquidGlassButton` (interactive buttons)
///   * `OcGlassBtn` (icon-typed buttons)
///
/// Pulling the math here keeps them visually in sync and gives a single
/// place to retune the glass look.
class GlassDecoration {
  GlassDecoration._();

  /// Standard drop-shadow used under every frosted surface in the app.
  ///
  /// [strength] tunes the dark-mode vs light-mode alpha. Defaults match
  /// the original inline values that LiquidGlassButton / OcGlassBtn used
  /// before consolidation.
  static BoxShadow shadow({
    required bool isDark,
    double strength = 1.0,
  }) {
    final alpha = (isDark ? 0.30 : 0.15) * strength;
    return BoxShadow(
      color: Colors.black.withValues(alpha: alpha),
      blurRadius: 10.w,
      offset: Offset(0, 4.h),
    );
  }

  /// Heavier shadow variant used by static [GlassCard] surfaces, which sit
  /// higher off the background than the interactive buttons.
  static BoxShadow cardShadow() => BoxShadow(
        color: const Color(0x33000000), // rgba(0,0,0,0.2)
        blurRadius: 40.w,
        offset: Offset(0, 8.h),
      );

  /// Theme-aware tint applied as the surface fill. [opacity] is the
  /// per-surface knob exposed by the public widget APIs.
  static Color tint({
    required bool isDark,
    double opacity = 0.23,
  }) {
    if (isDark) {
      return Colors.white.withValues(alpha: opacity * 0.26);
    }
    return Colors.black.withValues(alpha: opacity * 0.17);
  }
}
