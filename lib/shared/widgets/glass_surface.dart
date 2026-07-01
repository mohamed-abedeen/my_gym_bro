import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';

/// Telegram-style frosted glass surface — the shared glass primitive.
///
/// Recipe: a real Gaussian [BackdropFilter] blur of whatever is painted behind,
/// a translucent (theme-aware) tint, and a hairline border. Deliberately NOT a
/// refractive / "liquid" glass — no specular highlights or light bands (that was
/// the retired `oc_liquid_glass` look the user disliked).
///
/// Because it relies on [BackdropFilter], it only frosts content painted *behind*
/// it. Place it above the content you want blurred — e.g. in a [Stack] over a
/// scroll view, or as a transparent/extended app bar — not as an opaque page
/// background.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    this.width,
    this.height,
    this.opacity = 0.65,
    this.radius = AppRadius.card,
    this.blurSigma = AppGlass.blur,
    this.tint,
    this.border = true,
    this.borderColor,
    this.borderWidth = 0.7,
    this.shadow,
    this.padding,
    this.onTap,
    this.child,
  });

  final double? width;
  final double? height;

  /// Scales the default tint when [tint] is null. Kept for API compatibility
  /// with the previous (refractive) GlassSurface.
  final double opacity;
  final double radius;

  /// Gaussian blur strength. Defaults to [AppGlass.blur].
  final double blurSigma;

  /// Fill tint painted over the blur. When null, a theme-aware white frost
  /// scaled by [opacity] is used.
  final Color? tint;

  /// Draw the hairline glass border.
  final bool border;

  /// Override the hairline border color. Null → theme default ([AppGlass]).
  final Color? borderColor;

  /// Border stroke width. Defaults to a 0.7 hairline.
  final double borderWidth;

  /// Optional drop shadow, rendered outside the clip so it isn't clipped away.
  final BoxShadow? shadow;

  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = BorderRadius.circular(radius);

    final fill = tint ??
        (isDark
            ? Colors.white.withValues(alpha: opacity * 0.14)
            : Colors.white.withValues(alpha: opacity * 0.55));
    final borderClr =
        borderColor ?? (isDark ? AppGlass.borderDark : AppGlass.borderLight);

    Widget surface = ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: r,
            border: border
                ? Border.all(color: borderClr, width: borderWidth)
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (shadow != null) {
      surface = DecoratedBox(
        decoration: BoxDecoration(borderRadius: r, boxShadow: [shadow!]),
        child: surface,
      );
    }

    if (onTap != null) {
      surface = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: surface,
      );
    }

    return surface;
  }
}
