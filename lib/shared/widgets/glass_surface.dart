import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

/// A glass-surface container backed by [OCLiquidGlassGroup] + [OCLiquidGlass].
/// Drop any [child] inside to render it on a liquid-glass background.
class GlassSurface extends ConsumerWidget {
  const GlassSurface({
    super.key,
    required this.width,
    required this.height,
    this.opacity = 0.65,
    this.radius = 24.0,
    this.child,
  });

  final double width;
  final double height;
  final double opacity;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

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
      lightbandColor: Colors.white,
    );

    final tint = isDark
        ? Colors.white.withValues(alpha: opacity * 0.10)
        : Colors.black.withValues(alpha: opacity * 0.06);

    return SizedBox(
      width: width,
      height: height,
      child: OCLiquidGlassGroup(
        settings: settings,
        child: OCLiquidGlass(
          width: width,
          height: height,
          borderRadius: radius,
          color: tint,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
