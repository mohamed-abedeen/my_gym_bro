import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Glass icon button — Telegram-style frosted glass chips
// ─────────────────────────────────────────────────────────────────────────────

/// Icon type determines the icon, shape, and optional tint.
enum OcGlassBtnType {
  close, // X mark — circle
  done, // Checkmark — circle (white default, green when active)
  save, // Disk/label — pill
  share, // Upload/share — circle
  delete, // Trash — circle, red-tinted
  hint, // Info/lightbulb — circle
}

/// A frosted-glass icon button built on [GlassSurface].
///
/// Previously powered by the refractive `oc_liquid_glass` package; now renders
/// the app's Telegram-style frosted glass (real backdrop blur) while keeping its
/// original tints. Shape is circular by default; [OcGlassBtnType.save] renders
/// as a pill. Public API is unchanged.
class OcGlassBtn extends StatelessWidget {
  const OcGlassBtn({
    required this.type,
    this.onTap,
    this.isActive = false,
    this.label,
    this.size,
    super.key,
  });
  final OcGlassBtnType type;
  final VoidCallback? onTap;

  /// For [OcGlassBtnType.done]: when true the icon turns green.
  final bool isActive;

  /// Optional label shown next to the icon (only for pill-shaped buttons).
  final String? label;

  /// Override the default diameter (circle) or height (pill).
  final double? size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final d = (size ?? 48.0).w;
    final isPill = type == OcGlassBtnType.save;
    final pillW = isPill ? (label != null ? 120.0.w : 80.0.w) : d;
    final pillH = d;
    final radius = pillH / 2;

    final iconData = _iconFor(type);
    final iconColor = _iconColor(type, colors, isDark);
    final glassTint = _glassTint(type, colors, isDark);

    return GlassSurface(
      width: pillW,
      height: pillH,
      radius: radius,
      blurSigma: AppGlass.blurButton,
      tint: glassTint,
      shadow: GlassDecoration.shadow(isDark: isDark),
      onTap: onTap,
      child: Center(
        child: isPill && label != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconData, color: iconColor, size: 20.sp),
                  SizedBox(width: 6.w),
                  Text(
                    label!,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Icon(iconData, color: iconColor, size: 22.sp),
      ),
    );
  }

  // ── Icon mapping ──

  IconData _iconFor(OcGlassBtnType t) => switch (t) {
        OcGlassBtnType.close => Icons.close_rounded,
        OcGlassBtnType.done => Icons.check_rounded,
        OcGlassBtnType.save => Icons.save_rounded,
        OcGlassBtnType.share => Icons.ios_share_rounded,
        OcGlassBtnType.delete => Icons.delete_outline_rounded,
        OcGlassBtnType.hint => Icons.lightbulb_outline_rounded,
      };

  // ── Icon color ──

  Color _iconColor(OcGlassBtnType t, AppColorsTheme c, bool isDark) =>
      switch (t) {
        OcGlassBtnType.done =>
          isActive ? c.success : (isDark ? c.white : c.black),
        OcGlassBtnType.delete => c.danger,
        OcGlassBtnType.hint => c.accent,
        _ => isDark ? c.white : c.black,
      };

  // ── Glass fill tint (over the blur) — preserves the original look ──

  Color _glassTint(OcGlassBtnType t, AppColorsTheme c, bool isDark) =>
      t == OcGlassBtnType.delete
          ? c.danger.withValues(alpha: isDark ? 0.10 : 0.08)
          : GlassDecoration.tint(isDark: isDark);
}
