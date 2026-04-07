import 'dart:math';
import 'package:flutter/widgets.dart';

/// Responsive scaling utility.
///
/// Figma design is 440×956 (iPhone 17 Pro Max).
/// All pixel values from Figma are scaled proportionally to the actual device.
///
/// Usage:
///   Responsive.init(context);  // call once per build (scaffold level)
///   20.w   // width-scaled (horizontal sizes, padding, margins, radius)
///   20.h   // height-scaled (vertical sizes)
///   16.sp  // font-size scaled (uses width factor, clamped for readability)
class Responsive {
  Responsive._();

  static const double designWidth = 440.0;
  static const double designHeight = 956.0;

  static double _sw = 1.0;
  static double _sh = 1.0;

  /// Call once from a widget that has access to [BuildContext].
  /// Typically in the scaffold or top-level screen.
  static void init(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _sw = size.width / designWidth;
    _sh = size.height / designHeight;
  }

  static double get sw => _sw;
  static double get sh => _sh;

  /// Scale a value by width ratio.
  static double w(double v) => v * _sw;

  /// Scale a value by height ratio.
  static double h(double v) => v * _sh;

  /// Scale a font size — uses width factor, clamped so text never
  /// becomes unreadably small or oversized on extreme screens.
  static double sp(double v) {
    final scale = min(_sw, _sh);
    return v * scale;
  }
}

/// Extension on [num] for concise responsive values.
///
/// ```dart
/// SizedBox(width: 194.w, height: 179.h)
/// Text('Hello', style: TextStyle(fontSize: 24.sp))
/// BorderRadius.circular(25.r)
/// ```
extension ResponsiveNum on num {
  /// Width-scaled value (horizontal dimensions, padding, margins).
  double get w => Responsive.w(toDouble());

  /// Height-scaled value (vertical dimensions).
  double get h => Responsive.h(toDouble());

  /// Font-size scaled value.
  double get sp => Responsive.sp(toDouble());

  /// Radius-scaled value (same as width-scaled).
  double get r => Responsive.w(toDouble());
}
