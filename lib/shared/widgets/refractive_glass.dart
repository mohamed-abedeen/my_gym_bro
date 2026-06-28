import 'package:flutter/material.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

/// Refractive "liquid glass" surface — the oc_liquid_glass shader look used by
/// the (non-iOS) bottom nav pill.
///
/// Opt-in alternative to the frosted GlassSurface, for the few places the user
/// wants the refractive look (currently the active-workout chrome). It's a
/// Flutter fragment shader (not a platform view), so it composites in Flutter's
/// own layer and is fine to use inside lists — unlike the native iOS glass.
/// Self-contained: wraps its own [OCLiquidGlassGroup].
class RefractiveGlass extends StatelessWidget {
  const RefractiveGlass({
    required this.width,
    required this.height,
    this.radius = 24.0,
    this.tint,
    this.shadow,
    this.child,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  /// Fill tint painted over the shader. Null → a subtle theme-aware default.
  final Color? tint;
  final BoxShadow? shadow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Matched to the BottomNavPill settings for a consistent refractive look.
    final settings = OCLiquidGlassSettings(
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

    final fill = tint ??
        (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04));

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
