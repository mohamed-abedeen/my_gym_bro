import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';

/// HIG-style building blocks for the settings screen.
///
/// Follows the patterns of Apple's first-party apps (Fitness, Health,
/// Journal) rather than the Settings app: inset grouped cards on frosted
/// [GlassSurface] (per the glass system: general surfaces → frosted),
/// icon-less content-first rows, footnote group footers, and centered
/// text-button rows for destructive actions.

// ─────────────────────────────────────────────────────────────────────────────
// Section — header, grouped card, footnote footer
// ─────────────────────────────────────────────────────────────────────────────

/// A grouped card of rows with an optional header above and an optional
/// explanatory footnote below (the Apple "group footer" pattern).
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.children,
    this.header,
    this.footer,
    super.key,
  });

  /// Uppercase mini-header rendered above the card. Null → no header.
  final String? header;

  /// Footnote text rendered under the card. Null → no footer.
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Padding(
          padding: EdgeInsets.only(left: 16.w),
          child: Container(
            height: 0.7,
            color: colors.divider.withValues(alpha: 0.5),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: EdgeInsets.only(left: 16.w, bottom: 7.h),
            child: Text(
              header!.toUpperCase(),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
                color: colors.subtitleText,
              ),
            ),
          ),
        GlassSurface(
          width: double.infinity,
          radius: 22.r,
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 7.h),
            child: Text(
              footer!,
              style: TextStyle(
                fontSize: 11.5.sp,
                height: 1.35,
                color: colors.subtitleText,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pressable shell — shared press-highlight behaviour
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

/// Public pressable wrapper for custom row content (e.g. the subscription
/// card) so it gets the same press-highlight behaviour as the standard rows.
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
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
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
    required this.label,
    this.value,
    this.onTap,
    super.key,
  });

  final String label;

  /// Current value rendered dimmed before the chevron.
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return _PressableRow(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
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
                    fontSize: 14.sp,
                    color: colors.subtitleText,
                  ),
                ),
              ),
            ],
            SizedBox(width: 5.w),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary.withValues(alpha: 0.6),
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
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
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
              activeTrackColor: colors.accent,
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
    required this.label,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

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
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
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

// ─────────────────────────────────────────────────────────────────────────────
// Button row — centered text action (Apple grouped-list button pattern)
// ─────────────────────────────────────────────────────────────────────────────

/// Centered text-button row, e.g. Sign Out / Delete Account.
class SettingsButtonRow extends StatelessWidget {
  const SettingsButtonRow({
    required this.label,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _PressableRow(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
