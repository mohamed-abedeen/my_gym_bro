import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';

/// Flat frosted-glass button. Shares its visual language (tint + shadow)
/// with the other glass surfaces via [GlassDecoration].
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

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: GlassDecoration.tint(isDark: isDark, opacity: opacity),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [GlassDecoration.shadow(isDark: isDark)],
        ),
        child: Center(child: child),
      ),
    );
  }
}
