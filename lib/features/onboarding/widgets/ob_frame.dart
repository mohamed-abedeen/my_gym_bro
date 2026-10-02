import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/constants.dart';

/// Maps the handoff's 440×956 artboard onto the device.
///
/// One uniform scale keeps every position, size and type size in the
/// design's proportions (nearly every current phone shares the artboard's
/// ~0.46 aspect ratio). The scale is also bounded so the artboard's
/// "content band" — y 62 (first visible pixel under the status bar) to
/// y 922 (bottom of the Continue button) — always fits between the device's
/// real safe-area insets, and the artboard is centred within those bounds.
///
/// Screens lay out in design coordinates: `ob(33)` scales a length,
/// `ob.at(...)` positions a child inside the artboard [Stack].
class ObFrame extends InheritedWidget {
  const ObFrame._({
    required this.scale,
    required this.origin,
    required this.screen,
    required super.child,
  });

  /// Design units → logical pixels.
  final double scale;

  /// Artboard top-left, in screen coordinates.
  final Offset origin;

  /// Full screen size.
  final Size screen;

  static const double _contentTop = 62;
  static const double _contentBottom = 922;

  /// Scales a design-space length.
  double call(num v) => v * scale;

  Size get artboardSize => Size(
        AppOnboarding.artboardWidth * scale,
        AppOnboarding.artboardHeight * scale,
      );

  /// Positions [child] at design coordinates inside an artboard [Stack].
  Positioned at({
    required Widget child,
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? width,
    double? height,
  }) =>
      Positioned(
        left: left == null ? null : this(left),
        top: top == null ? null : this(top),
        right: right == null ? null : this(right),
        bottom: bottom == null ? null : this(bottom),
        width: width == null ? null : this(width),
        height: height == null ? null : this(height),
        child: child,
      );

  /// A full-width, centred text row at design `top` (the handoff's
  /// `left:0;right:0;text-align:center` pattern), with optional side insets.
  Positioned centered({
    required double top,
    required Widget child,
    double inset = 0,
  }) =>
      Positioned(
        left: this(inset),
        right: this(inset),
        top: this(top),
        child: Center(child: child),
      );

  /// System UI text (SF Pro on iOS, Roboto on Android).
  TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = AppOnboarding.textPrimary,
    double? lineHeight,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: this(size),
        fontWeight: weight,
        color: color,
        height: lineHeight == null ? null : lineHeight / size,
        letterSpacing: letterSpacing == null ? null : this(letterSpacing),
      );

  /// Archivo condensed display type (`font-stretch: 62%`).
  TextStyle display(
    double size, {
    double weight = 800,
    Color color = AppOnboarding.textPrimary,
    double? lineHeight,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'Archivo',
        fontSize: this(size),
        color: color,
        fontWeight: FontWeight.values[weight ~/ 100 - 1],
        fontVariations: [
          FontVariation('wght', weight),
          const FontVariation('wdth', 62),
        ],
        height: lineHeight == null ? null : lineHeight / size,
        letterSpacing: letterSpacing == null ? null : this(letterSpacing),
      );

  /// IBM Plex Mono SemiBold — numbers and tickers.
  TextStyle mono(
    double size, {
    Color color = AppOnboarding.textPrimary,
  }) =>
      TextStyle(
        fontFamily: 'IBMPlexMono',
        fontWeight: FontWeight.w600,
        fontSize: this(size),
        color: color,
      );

  /// Design-space y of the device's bottom safe edge, so bottom-anchored
  /// chrome can clear a home indicator / nav bar taller than the design's.
  double safeBottomY(EdgeInsets padding) =>
      (screen.height - padding.bottom - origin.dy) / scale;

  static ObFrame of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ObFrame>()!;

  /// Computes the frame for [screen] with safe-area [padding].
  static ObFrame fit({
    required Size screen,
    required EdgeInsets padding,
    required Widget child,
  }) {
    const w = AppOnboarding.artboardWidth;
    const h = AppOnboarding.artboardHeight;
    final usable = screen.height - padding.top - padding.bottom;
    final scale = [
      screen.width / w,
      screen.height / h,
      usable / (_contentBottom - _contentTop),
    ].reduce(math.min);

    final centred = (screen.height - h * scale) / 2;
    final minY = padding.top - _contentTop * scale;
    final maxY = screen.height - padding.bottom - _contentBottom * scale;
    final top = maxY < minY ? minY : centred.clamp(minY, maxY);

    return ObFrame._(
      scale: scale,
      origin: Offset((screen.width - w * scale) / 2, top),
      screen: screen,
      child: child,
    );
  }

  @override
  bool updateShouldNotify(ObFrame oldWidget) =>
      oldWidget.scale != scale ||
      oldWidget.origin != origin ||
      oldWidget.screen != screen;
}

/// Provides an [ObFrame] for the full screen it's given.
class ObFrameScope extends StatelessWidget {
  const ObFrameScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return ObFrame.fit(
      screen: mq.size,
      padding: mq.padding,
      child: child,
    );
  }
}

/// A full-screen black page whose [children] are laid out in artboard
/// coordinates (via [ObFrame.at]).
class ObArtboard extends StatelessWidget {
  const ObArtboard({required this.children, this.background, super.key});

  final List<Widget> children;

  /// Painted full-screen, behind the artboard (e.g. a full-bleed hero).
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final ob = ObFrame.of(context);
    final size = ob.artboardSize;
    return ColoredBox(
      color: AppOnboarding.background,
      child: Stack(
        children: [
          if (background != null) Positioned.fill(child: background!),
          Positioned(
            left: ob.origin.dx,
            top: ob.origin.dy,
            width: size.width,
            height: size.height,
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        ],
      ),
    );
  }
}
