import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';
import 'package:my_gym_bro/shared/responsive.dart';

/// Severity of the action being confirmed — drives badge/primary styling.
enum ConfirmTier {
  /// Reversible (e.g. finish workout) — accent primary, optional summary.
  reversible,

  /// Destructive but recoverable-ish (discard, delete, sign out) — danger.
  destructive,

  /// Permanent (delete account) — danger primary becomes hold-to-confirm.
  permanent,
}

/// One column of the tier-1 session summary strip.
class ConfirmSummaryItem {
  const ConfirmSummaryItem({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;

  /// Renders the value in the success colour (used for the PR count).
  final bool highlight;
}

/// Shared confirmation bottom sheet (design handoff "option 1a").
///
/// Replaces the stock confirmation [AlertDialog]s: one sheet, three severity
/// tiers. Resolves `true` on confirm; Cancel, scrim tap, and drag-down all
/// resolve `false`, so call sites keep the `await`-a-bool contract.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required ConfirmTier tier,
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
  IconData? icon,
  List<ConfirmSummaryItem>? summary,
}) async {
  unawaited(HapticFeedback.selectionClick());
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.of(context).overlayBlack,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    ),
    builder: (ctx) => _ConfirmSheet(
      tier: tier,
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      icon: icon,
      summary: summary,
    ),
  );
  return result ?? false;
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.tier,
    required this.title,
    required this.body,
    required this.confirmLabel,
    this.cancelLabel,
    this.icon,
    this.summary,
  });

  final ConfirmTier tier;
  final String title;
  final String body;
  final String confirmLabel;
  final String? cancelLabel;
  final IconData? icon;
  final List<ConfirmSummaryItem>? summary;

  static const _defaultIcons = {
    ConfirmTier.reversible: Icons.check_circle_rounded,
    ConfirmTier.destructive: Icons.delete_outline_rounded,
    ConfirmTier.permanent: Icons.delete_forever_rounded,
  };

  void _confirm(BuildContext context) {
    unawaited(HapticFeedback.mediumImpact());
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tierColor =
        tier == ConfirmTier.reversible ? colors.accent : colors.danger;
    final badgeFill = tierColor.withValues(
      alpha: tier == ConfirmTier.reversible ? 0.16 : 0.14,
    );
    final secondaryFill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final grabberColor = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.2);
    final items = summary;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: title,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.panelBackground,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.sheet.r)),
          border: Border(
            top: BorderSide(
              color: isDark ? AppGlass.borderDark : AppGlass.borderLight,
              width: 0.7,
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          24.w,
          14.h,
          24.w,
          24.h + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: grabberColor,
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            ),
            SizedBox(height: 22.h),
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: badgeFill,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(
                icon ?? _defaultIcons[tier],
                size: 24.sp,
                color: tierColor,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              body,
              style: TextStyle(
                color: colors.subtitleText,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
            if (items != null && items.isNotEmpty) ...[
              SizedBox(height: 18.h),
              _SummaryStrip(items: items),
              SizedBox(height: 24.h),
            ] else
              SizedBox(height: 24.h),
            if (tier == ConfirmTier.permanent)
              _HoldToConfirmButton(
                label: confirmLabel,
                onConfirmed: () => Navigator.of(context).pop(true),
              )
            else
              _SheetButton(
                label: confirmLabel,
                background: tierColor,
                labelStyle: TextStyle(
                  color: tier == ConfirmTier.reversible
                      ? Colors.black
                      : Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
                onTap: () => _confirm(context),
              ),
            SizedBox(height: 10.h),
            _SheetButton(
              label: cancelLabel ?? l10n.cancel,
              background: secondaryFill,
              labelStyle: TextStyle(
                color: colors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary strip (tier 1) — time / exercises / sets / new PR
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.items});

  final List<ConfirmSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // At large text sizes (app clamps at 1.3) four columns can't fit — drop
    // to two columns per row instead of shrinking type.
    final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final perRow = textScale >= 1.29 ? 2 : items.length;

    Widget cell(ConfirmSummaryItem item) => Expanded(
          child: Column(
            children: [
              Text(
                item.value,
                style: TextStyle(
                  color: item.highlight ? colors.success : colors.textPrimary,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                item.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.subtitleText,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );

    final divider = Container(width: 1, height: 26.h, color: colors.separator);

    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += perRow) {
      final rowItems = items.sublist(
        i,
        (i + perRow).clamp(0, items.length),
      );
      if (rows.isNotEmpty) rows.add(SizedBox(height: 14.h));
      rows.add(
        Row(
          children: [
            for (var j = 0; j < rowItems.length; j++) ...[
              if (j > 0) divider,
              cell(rowItems[j]),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(children: rows),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buttons
// ─────────────────────────────────────────────────────────────────────────────

/// Full-width pill button with the 120ms pressed-dim from `_PressableRow`.
class _SheetButton extends StatefulWidget {
  const _SheetButton({
    required this.label,
    required this.background,
    required this.labelStyle,
    required this.onTap,
  });

  final String label;
  final Color background;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  State<_SheetButton> createState() => _SheetButtonState();
}

class _SheetButtonState extends State<_SheetButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            height: 52.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.background,
              borderRadius: BorderRadius.circular(26.r),
            ),
            child: Text(widget.label, style: widget.labelStyle),
          ),
        ),
      ),
    );
  }
}

/// Tier-3 primary: press and hold for 1200ms to confirm. Mirrors the
/// press-to-confirm delete bar used for sets in the active session screen.
///
/// With a screen reader / switch access (`accessibleNavigation`) a hold
/// gesture is not reliably performable, so the button degrades to an
/// explicit two-tap flow: first activation arms it, the second confirms.
class _HoldToConfirmButton extends StatefulWidget {
  const _HoldToConfirmButton({
    required this.label,
    required this.onConfirmed,
  });

  final String label;
  final VoidCallback onConfirmed;

  @override
  State<_HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<_HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _confirmed = false;
  bool _armed = false; // accessible two-tap path

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _complete();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete() {
    if (_confirmed) return;
    setState(() => _confirmed = true);
    unawaited(HapticFeedback.heavyImpact());
    // Leave the full bar + "Confirmed" visible for a beat before resolving.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) widget.onConfirmed();
    });
  }

  void _release() {
    if (!_confirmed) _controller.value = 0;
  }

  void _accessibleTap() {
    if (_confirmed) return;
    if (_armed) {
      _controller.value = 1; // status listener runs _complete()
    } else {
      setState(() => _armed = true);
      unawaited(HapticFeedback.selectionClick());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accessible = MediaQuery.accessibleNavigationOf(context);
    final labelColor = isDark ? Colors.white : colors.textPrimary;

    final String label;
    final IconData iconData;
    if (_confirmed) {
      label = l10n.holdConfirmed;
      iconData = Icons.check_rounded;
    } else if (accessible && _armed) {
      label = l10n.tapAgainToConfirm;
      iconData = Icons.touch_app_rounded;
    } else {
      label = widget.label;
      iconData = Icons.touch_app_rounded;
    }

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: accessible ? _accessibleTap : null,
        onTapDown: accessible || _confirmed
            ? null
            : (_) => _controller.forward(),
        onTapUp: accessible ? null : (_) => _release(),
        onTapCancel: accessible ? null : _release,
        child: Container(
          height: 52.h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.danger.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(26.r),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _controller.value,
                  child: ColoredBox(color: colors.danger),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconData, size: 20.sp, color: labelColor),
                    SizedBox(width: 8.w),
                    Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
