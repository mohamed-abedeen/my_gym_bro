import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';

/// Telegram-style frosted-glass button.
///
/// Reimplemented on top of [GlassSurface]: a real backdrop blur with the same
/// tint + shadow it used before (via [GlassDecoration]). The public API is
/// unchanged, so every call site keeps working — buttons just gain the real
/// frosted-glass look instead of a flat tint.
class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton({
    required this.child,
    required this.width,
    required this.height,
    this.opacity = 0.23,
    this.radius = AppRadius.button,
    this.onTap,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double opacity;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassSurface(
      width: width,
      height: height,
      radius: radius,
      blurSigma: AppGlass.blurButton,
      tint: GlassDecoration.tint(isDark: isDark, opacity: opacity),
      shadow: GlassDecoration.shadow(isDark: isDark),
      onTap: onTap,
      child: Center(child: child),
    );
  }
}
