import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';

/// iOS-Settings-style building blocks for the redesigned settings screen.
///
/// A section is a frosted [GlassSurface] card (per the glass system: general
/// surfaces → frosted) holding compact rows: leading tinted icon badge,
/// label, trailing value/control, hairline inset dividers.

// ─────────────────────────────────────────────────────────────────────────────
// Icon badge palette — fixed decorative colors (iOS system palette), shared
// by both themes so sections read the same in light and dark.
// ─────────────────────────────────────────────────────────────────────────────

/// Decorative badge colors for settings rows.
class SettingsBadgeColors {
  SettingsBadgeColors._();

  static const purple = Color(0xFFAF52DE);
  static const indigo = Color(0xFF5856D6);
  static const teal = Color(0xFF30B0C7);
  static const blue = Color(0xFF007AFF);
  static const green = Color(0xFF34C759);
  static const orange = Color(0xFFFF9500);
  static const pink = Color(0xFFFF2D55);
  static const red = Color(0xFFFF3B30);
  static const yellow = Color(0xFFFFCC00);
  static const gray = Color(0xFF8E8E93);
}

// ─────────────────────────────────────────────────────────────────────────────
// Section
// ─────────────────────────────────────────────────────────────────────────────

/// A titled group of settings rows on a single frosted card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    this.header,
    super.key,
  });

  /// Uppercase mini-header rendered above the card. Null → no header.
  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: 54.w),
          child: Container(height: 0.7, color: colors.divider.withValues(alpha: 0.55)),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: EdgeInsets.only(left: 18.w, bottom: 7.h),
            child: Text(
              header!.toUpperCase(),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: colors.subtitleText,
              ),
            ),
          ),
        GlassSurface(
          width: double.infinity,
          radius: 22.r,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon badge
// ─────────────────────────────────────────────────────────────────────────────

/// Rounded-square tinted icon container (the iOS Settings leading icon).
class SettingsIconBadge extends StatelessWidget {
  const SettingsIconBadge({
    required this.icon,
    required this.color,
    super.key,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30.w,
      height: 30.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.5.r),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.18)!,
            color,
          ],
        ),
      ),
      child: Icon(icon, color: Colors.white, size: 17.sp),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row scaffold — press highlight shared by tappable rows
// ─────────────────────────────────────────────────────────────────────────────

class _PressableRow extends StatefulWidget {
  const _PressableRow({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<_PressableRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed
            ? colors.textPrimary.withValues(alpha: 0.07)
            : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

/// Public pressable wrapper for custom row content (e.g. the profile hero
/// row) so it gets the same press-highlight behaviour as the standard rows.
class SettingsNavRowShell extends StatelessWidget {
  const SettingsNavRowShell({
    required this.child,
    this.onTap,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableRow(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation row — label, optional value, chevron
// ─────────────────────────────────────────────────────────────────────────────

/// Tappable disclosure row (opens a sheet, modal, or external link).
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.value,
    this.isDestructive = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  /// Current value rendered dimmed before the chevron.
  final String? value;
  final bool isDestructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final labelColor = isDestructive ? colors.danger : colors.textPrimary;

    return _PressableRow(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
        child: Row(
          children: [
            SettingsIconBadge(icon: icon, color: iconColor),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
            if (value != null) ...[
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: colors.subtitleText,
                  ),
                ),
              ),
            ],
            SizedBox(width: 4.w),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary.withValues(alpha: 0.7),
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Switch row
// ─────────────────────────────────────────────────────────────────────────────

/// Row with an inline adaptive switch. Fires a selection haptic on toggle.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      child: Row(
        children: [
          SettingsIconBadge(icon: icon, color: iconColor),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            alignment: Alignment.centerRight,
            child: Switch.adaptive(
              value: value,
              // iOS system green — requested toggle color in both themes.
              activeTrackColor: const Color(0xFF34C759),
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented row — inline 2–3 option picker (no bottom sheet needed)
// ─────────────────────────────────────────────────────────────────────────────

/// Row with a compact segmented control on the trailing edge.
class SettingsSegmentedRow extends StatelessWidget {
  const SettingsSegmentedRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thumbColor = isDark ? const Color(0xFF636366) : Colors.white;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          SettingsIconBadge(icon: icon, color: iconColor),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < options.length; i++)
                  GestureDetector(
                    onTap: () {
                      if (i != selectedIndex) {
                        HapticFeedback.selectionClick();
                        onChanged(i);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: i == selectedIndex
                            ? thumbColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7.r),
                        boxShadow: i == selectedIndex
                            ? [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        options[i],
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: i == selectedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: i == selectedIndex
                              ? colors.textPrimary
                              : colors.subtitleText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
