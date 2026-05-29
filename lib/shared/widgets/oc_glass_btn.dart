import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_gym_bro/core/providers/providers.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/bottom_nav_pill.dart'
    show BottomNavPill;
import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';

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

/// A high-fidelity iOS 26 Liquid-Glass button powered by the `oc_liquid_glass` package.
///
/// Uses the same shader settings as [BottomNavPill] for visual consistency.
/// Shape is circular by default; [OcGlassBtnType.save] renders as a pill.
class OcGlassBtn extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final diameter = size ?? 48.0;
    final d = diameter.w;
    final isPill = type == OcGlassBtnType.save;
    final pillW = isPill ? (label != null ? 120.0.w : 80.0.w) : d;
    final pillH = d;
    final radius = isPill ? d / 2 : d / 2;

    // Icon + color resolution.
    final iconData = _iconFor(type);
    final iconColor = _iconColor(type, colors, isDark);
    final bgColor = _glassColor(type, colors, isDark);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: pillW,
        height: pillH,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [GlassDecoration.shadow(isDark: isDark)],
        ),
        child: Center(
          child:
              isPill && label != null
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

  // ── Glass fill tint ──

  Color _glassColor(
    OcGlassBtnType t,
    AppColorsTheme c,
    bool isDark,
  ) => switch (t) {
    OcGlassBtnType.delete => c.danger.withValues(alpha: isDark ? 0.10 : 0.08),
    _ =>
      isDark
          ? c.white.withValues(alpha: 0.06)
          : c.black.withValues(alpha: 0.04),
  };
}
