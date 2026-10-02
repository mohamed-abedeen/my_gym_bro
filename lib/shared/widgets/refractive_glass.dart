import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart' show GlassSurface;
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

/// Refractive "liquid glass" surface — the oc_liquid_glass shader look
/// (iOS-26-ish refraction, specular rim and light band).
///
/// Opt-in alternative to the frosted GlassSurface, for the places that want
/// the refractive look (the workout tab's floating session bar, the
/// onboarding buttons). Self-contained: wraps its own [OCLiquidGlassGroup].
///
/// Falls back to the frosted [GlassSurface], with the same tint and shadow,
/// wherever the shader can't be used (see [refractsAt]):
///  * inside a scrolling viewport — the shader is an unclipped BackdropFilter
///    that force-writes opaque pixels across the whole enclosing clip, so in
///    a list on Android (Impeller) it paints the entire viewport black while
///    scrolling (visible in light mode);
///  * on renderers without shader-filter support (Skia, widget tests), where
///    the package would paint the child with no glass and no tint at all.
class RefractiveGlass extends StatelessWidget {
  const RefractiveGlass({
    required this.width,
    required this.height,
    this.radius = 24.0,
    this.tint,
    this.shadow,
    this.settings,
    this.child,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  /// Fill tint painted over the shader. Null → a subtle theme-aware default.
  final Color? tint;
  final BoxShadow? shadow;

  /// Shader settings. Null → the subtle look matched to the bottom nav (its
  /// negative specular darkens the rim rather than lighting it).
  final OCLiquidGlassSettings? settings;
  final Widget? child;

  /// iOS 26 button glass: a thin light rim all round, bright specular arcs
  /// where the light hits the top-left and bottom-right caps, a little
  /// frost, and lensing near the edges (the package's default -0.06
  /// refraction). Light comes from the top-left — the package's default
  /// `specAngle` — and its mirror. For button-sized pills.
  static const buttonSettings = OCLiquidGlassSettings(
    blendPx: 3,
    distortFalloffPx: 24,
    blurRadiusPx: 3,
    specStrength: 1,
    specPower: 10,
    specWidth: 3,
    lightbandOffsetPx: 1.5,
    lightbandWidthPx: 3,
    lightbandStrength: 0.35,
  );

  /// Whether a [RefractiveGlass] built at [context] renders the shader rather
  /// than the frosted fallback.
  static bool refractsAt(BuildContext context) =>
      ImageFilter.isShaderFilterSupported &&
      context.findAncestorStateOfType<ScrollableState>() == null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fill = tint ??
        (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04));

    if (!refractsAt(context)) {
      return GlassSurface(
        width: width,
        height: height,
        radius: radius,
        blurSigma: AppGlass.blurButton,
        tint: fill,
        shadow: shadow,
        child: child,
      );
    }

    // Default: matched to the BottomNavPill settings for a consistent look.
    final settings = this.settings ??
        OCLiquidGlassSettings(
          blendPx: 3,
          refractStrength: isDark ? 0.01 : 0.1,
          distortFalloffPx: 13,
          blurRadiusPx: isDark ? 4 : 5.5,
          specAngle: 0.1,
          specStrength: -1,
          specPower: 1,
          specWidth: 1.7,
          lightbandOffsetPx: 3,
          lightbandWidthPx: 3.5,
          lightbandStrength: isDark ? 0.6 : 0.4,
        );

    return SizedBox(
      width: width,
      height: height,
      child: OCLiquidGlassGroup(
        settings: settings,
        child: OCLiquidGlass(
          width: width,
          height: height,
          borderRadius: radius,
          color: fill,
          shadow: shadow,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
