import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OcIcon — Renders a custom SVG icon from assets/icons/
//
// Use with OcIcons constants:
//   OcIcon(OcIcons.like)
//   OcIcon(OcIcons.share, size: 20, color: Theme.of(context).colorScheme.primary)
// ─────────────────────────────────────────────────────────────────────────────

class OcIcon extends StatelessWidget {
  const OcIcon(
    this.assetPath, {
    this.size = 24.0,
    this.color,
    super.key,
  });

  /// Asset path — use a constant from [OcIcons], e.g. `OcIcons.like`.
  final String assetPath;

  /// Width and height in logical pixels. Defaults to 24.
  final double size;

  /// Tint color applied via [BlendMode.srcIn]. Defaults to current icon theme
  /// color, then the theme's onSurface color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;

    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
    );
  }
}
