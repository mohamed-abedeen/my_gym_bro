import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/refractive_glass.dart';

/// Telegram-style frosted-glass button (default), with an opt-in [refractive]
/// mode that renders the oc_liquid_glass look instead (matches the nav pill).
///
/// Built on [GlassSurface] (frost) or [RefractiveGlass] (refractive). The public
/// API is otherwise unchanged, so every call site keeps working.
class LiquidGlassButton extends StatelessWidget {
  const LiquidGlassButton({
    required this.child,
    required this.width,
    required this.height,
    this.opacity = 0.23,
    this.radius = AppRadius.button,
    this.onTap,
    this.refractive = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double opacity;
  final double radius;

  /// Refractive oc_liquid_glass look (like the bottom nav) instead of frost.
  final bool refractive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadow = GlassDecoration.shadow(isDark: isDark);
    final content = Center(child: child);

    final Widget surface = refractive
        ? RefractiveGlass(
            width: width,
            height: height,
            radius: radius,
            shadow: shadow,
            child: content,
          )
        : GlassSurface(
            width: width,
            height: height,
            radius: radius,
            blurSigma: AppGlass.blurButton,
            tint: GlassDecoration.tint(isDark: isDark, opacity: opacity),
            shadow: shadow,
            child: content,
          );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: surface,
    );
  }
}
