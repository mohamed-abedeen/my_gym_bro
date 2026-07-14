import 'package:flutter/material.dart';

import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';
import 'package:my_gym_bro/shared/widgets/refractive_glass.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Glass icon button — frosted by default, opt-in refractive (like the nav)
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

/// A glass icon button. Telegram-style frosted glass by default; pass
/// [refractive] = true for the oc_liquid_glass refractive look (matches the
/// bottom nav). Shape is circular by default; [OcGlassBtnType.save] is a pill.
class OcGlassBtn extends StatelessWidget {
  const OcGlassBtn({
    required this.type,
    this.onTap,
    this.isActive = false,
    this.label,
    this.size,
    this.refractive = false,
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

  /// Refractive oc_liquid_glass look (like the bottom nav) instead of frost.
  final bool refractive;

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
    final shadow = GlassDecoration.shadow(isDark: isDark);

    final content = Center(
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
    );

    final Widget surface = refractive
        ? RefractiveGlass(
            width: pillW,
            height: pillH,
            radius: radius,
            tint: glassTint,
            shadow: shadow,
            child: content,
          )
        : GlassSurface(
            width: pillW,
            height: pillH,
            radius: radius,
            blurSigma: AppGlass.blurButton,
            tint: glassTint,
            shadow: shadow,
            child: content,
          );

    // Every OcGlassBtn knows its type, so it can label itself for screen
    // readers: the visible pill label wins, otherwise a localized default.
    // excludeSemantics drops the inner Text so nothing announces twice; the
    // GestureDetector above the Semantics keeps the tap action.
    return Semantics(
      container: true,
      button: true,
      label: label ?? _semanticLabel(type, AppLocalizations.of(context)),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(child: surface),
      ),
    );
  }

  // ── Default screen-reader label per type ──

  String _semanticLabel(OcGlassBtnType t, AppLocalizations l10n) => switch (t) {
    OcGlassBtnType.close => l10n.close,
    OcGlassBtnType.done => l10n.done,
    OcGlassBtnType.save => l10n.save,
    OcGlassBtnType.share => l10n.share,
    OcGlassBtnType.delete => l10n.delete,
    OcGlassBtnType.hint => l10n.hint,
  };

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

  // ── Glass fill tint (over the blur / shader) ──

  Color _glassTint(OcGlassBtnType t, AppColorsTheme c, bool isDark) =>
      t == OcGlassBtnType.delete
      ? c.danger.withValues(alpha: isDark ? 0.10 : 0.08)
      : GlassDecoration.tint(isDark: isDark);
}
