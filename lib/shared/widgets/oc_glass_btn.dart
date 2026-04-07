import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

import '../../core/providers/providers.dart';
import '../constants.dart';
import '../responsive.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OC Liquid Glass Button — iOS 26 style refractive glass icon buttons
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

/// A high-fidelity iOS 26 Liquid-Glass button powered by [oc_liquid_glass].
///
/// Uses the same shader settings as [BottomNavPill] for visual consistency.
/// Shape is circular by default; [OcGlassBtnType.save] renders as a pill.
class OcGlassBtn extends ConsumerWidget {
  final OcGlassBtnType type;
  final VoidCallback? onTap;

  /// For [OcGlassBtnType.done]: when true the icon turns green.
  final bool isActive;

  /// Optional label shown next to the icon (only for pill-shaped buttons).
  final String? label;

  /// Override the default diameter (circle) or height (pill).
  final double? size;

  const OcGlassBtn({
    required this.type,
    this.onTap,
    this.isActive = false,
    this.label,
    this.size,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final diameter = size ?? 48.0;
    final d = diameter.w;
    final isPill = type == OcGlassBtnType.save;
    final pillW = isPill ? (label != null ? 120.0.w : 80.0.w) : d;
    final pillH = d;
    final radius = isPill ? d / 2 : d / 2;

    // Shader settings — matched to BottomNavPill for consistency.
    final glassSettings = OCLiquidGlassSettings(
      blendPx: 3,
      refractStrength: isDark ? -0.06 : -0.04,
      distortFalloffPx: 20,
      blurRadiusPx: isDark ? 3.0 : 2.5,
      specAngle: 0.8,
      specStrength: isDark ? 18.0 : 12.0,
      specPower: 4,
      specWidth: 1.5,
      lightbandOffsetPx: 2,
      lightbandWidthPx: 1.5,
      lightbandStrength: isDark ? 0.6 : 0.4,
      lightbandColor: isDark ? Colors.white70 : Colors.white,
    );

    // Icon + color resolution.
    final iconData = _iconFor(type);
    final iconColor = _iconColor(type, colors, isDark);
    final glassColor = _glassColor(type, colors, isDark);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: pillW,
        height: pillH,
        child: OCLiquidGlassGroup(
          settings: glassSettings,
          child: Stack(
            children: [
              OCLiquidGlass(
                width: pillW,
                height: pillH,
                borderRadius: radius,
                color: glassColor,
                shadow: BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.12),
                  blurRadius: 20.w,
                  offset: Offset(0, 6.h),
                ),
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
              ),
            ],
          ),
        ),
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
          isActive ? c.success : (isDark ? Colors.white : Colors.black),
        OcGlassBtnType.delete => c.danger,
        OcGlassBtnType.hint => c.accent,
        _ => isDark ? Colors.white : Colors.black,
      };

  // ── Glass fill tint ──

  Color _glassColor(OcGlassBtnType t, AppColorsTheme c, bool isDark) =>
      switch (t) {
        OcGlassBtnType.delete =>
          c.danger.withValues(alpha: isDark ? 0.10 : 0.08),
        _ => isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
      };
}
