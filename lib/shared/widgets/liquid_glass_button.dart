import 'package:flutter/material.dart';

import '../constants.dart';
import '../responsive.dart';

/// Liquid glass button matching the Figma 3-layer glass spec.
///
/// Flutter approximation: single color [Colors.white] at [opacity] with shadow.
///
/// Opacity constants from Figma CSS:
/// ```
/// navPill:       0.20
/// navActive:     0.25
/// actionButton:  0.23
/// actionStrong:  0.65
/// actionLight:   0.15
/// glassCard:     0.07
/// filterChip:    0.20
/// postPill:      0.20
/// ```
class LiquidGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double opacity;
  final double radius;

  const LiquidGlassButton({
    required this.child,
    required this.width,
    required this.height,
    this.opacity = 0.23,
    this.radius = AppRadius.button,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: const Color(0x1F000000), // rgba(0,0,0,0.12)
                blurRadius: 40.w,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      );
}
