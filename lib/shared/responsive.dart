import 'dart:math';
import 'package:flutter/widgets.dart';

/// Responsive scaling utility.
///
/// Figma design is 440×956 (iPhone 17 Pro Max).
/// All pixel values from Figma are scaled proportionally to the actual device.
///
/// Usage (in a widget's build method):
///   final r = Responsive.of(context);
///   SizedBox(width: r.w(194), height: r.h(179))
///   Text('Hello', style: TextStyle(fontSize: r.sp(24)))
///
/// Or via the convenient num extensions (require calling Responsive.init once):
///   20.w   // width-scaled
///   20.h   // height-scaled
///   16.sp  // font-size scaled
class Responsive {
  const Responsive._({required this.sw, required this.sh});

  static const double _designWidth = 440; // iPhone 17 Pro Max
  static const double _designHeight = 956;

  final double sw;
  final double sh;

  /// Returns a [Responsive] instance computed fresh from [context].
  /// Safe to call from any widget build — reads MediaQuery, no shared state.
  static Responsive of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Responsive._(
      sw: size.width / _designWidth,
      sh: size.height / _designHeight,
    );
  }

  /// Scale a value by width ratio.
  double w(double v) => v * sw;

  /// Scale a value by height ratio.
  double h(double v) => v * sh;

  /// Scale a font size — uses min(sw, sh) so text never becomes unreadably
  /// small or oversized on extreme screens.
  double sp(double v) => v * min(sw, sh);

  // ── Legacy static API ─────────────────────────────────────────────────────
  // Kept for backwards compatibility with existing `.w` / `.h` / `.sp` call
  // sites. Call [init] once from the outermost scaffold build before using the
  // extensions. New code should prefer [Responsive.of(context)].

  static double _sw = 1;
  static double _sh = 1;

  /// Initialise the legacy static scale factors from [context].
  /// Must be called before using the num extension getters below.
  static void init(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _sw = size.width / _designWidth;
    _sh = size.height / _designHeight;
  }

  static double wStatic(double v) => v * _sw;
  static double hStatic(double v) => v * _sh;
  static double spStatic(double v) => v * min(_sw, _sh);
}

/// Extension on [num] for concise responsive values.
/// Requires [Responsive.init] to have been called in the current build context.
///
/// ```dart
/// SizedBox(width: 194.w, height: 179.h)
/// Text('Hello', style: TextStyle(fontSize: 24.sp))
/// BorderRadius.circular(25.r)
/// ```
extension ResponsiveNum on num {
  double get w => Responsive.wStatic(toDouble());
  double get h => Responsive.hStatic(toDouble());
  double get sp => Responsive.spStatic(toDouble());
  double get r => Responsive.wStatic(toDouble());
}
