import 'package:flutter/material.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Flat button replacing the previous refractive liquid glass style.
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
          color: isDark
              ? AppColors.of(context).white.withValues(alpha: opacity * 0.26)
              : AppColors.of(context).black.withValues(alpha: opacity * 0.17),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: AppColors.of(context).black.withValues(alpha: isDark ? 0.30 : 0.15),
              blurRadius: 10.w,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
