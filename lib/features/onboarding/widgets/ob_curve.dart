import 'dart:ui';

/// The target-timeline S-curve from the handoff, in design units: a flat
/// lead-in, two cubic segments rising from "today" to the target plateau,
/// and a flat tail to the artboard edge.
enum ObCurve {
  /// Timeline steps: `M0,236 L52,236 C170,236 250,216 300,150
  /// C340,95 355,72 395,72 L440,72` (300-unit tall graph).
  timeline(236, 72, [
    [Offset(52, 236), Offset(170, 236), Offset(250, 216), Offset(300, 150)],
    [Offset(300, 150), Offset(340, 95), Offset(355, 72), Offset(395, 72)],
  ]),

  /// Paywall slide 1: the same shape 43 units higher, in a 258-unit box.
  paywall(193, 32, [
    [Offset(52, 193), Offset(170, 193), Offset(250, 175), Offset(300, 110)],
    [Offset(300, 110), Offset(340, 55), Offset(355, 32), Offset(395, 32)],
  ]);

  const ObCurve(this.startY, this.endY, this.segments);

  static const double width = 440;
  static const double todayX = 52;

  final double startY;
  final double endY;
  final List<List<Offset>> segments;

  double get startX => segments.first.first.dx;
  double get endX => segments.last.last.dx;

  /// The curve's y at design x (bisection on each cubic's x(t)).
  double yAt(double x) {
    if (x <= startX) return startY;
    if (x >= endX) return endY;
    final s = segments.firstWhere(
      (seg) => x <= seg.last.dx,
      orElse: () => segments.last,
    );
    var lo = 0.0;
    var hi = 1.0;
    for (var k = 0; k < 30; k++) {
      final mid = (lo + hi) / 2;
      if (_bez(s[0].dx, s[1].dx, s[2].dx, s[3].dx, mid) < x) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return _bez(s[0].dy, s[1].dy, s[2].dy, s[3].dy, (lo + hi) / 2);
  }

  /// The stroke path, scaled by [sx]/[sy].
  Path line({double sx = 1, double sy = 1}) {
    final p = Path()
      ..moveTo(0, startY * sy)
      ..lineTo(startX * sx, startY * sy);
    for (final s in segments) {
      p.cubicTo(
        s[1].dx * sx,
        s[1].dy * sy,
        s[2].dx * sx,
        s[2].dy * sy,
        s[3].dx * sx,
        s[3].dy * sy,
      );
    }
    return p..lineTo(width * sx, endY * sy);
  }

  /// The area under the curve down to [bottom] (design units).
  Path area({required double bottom, double sx = 1, double sy = 1}) =>
      line(sx: sx, sy: sy)
        ..lineTo(width * sx, bottom * sy)
        ..lineTo(0, bottom * sy)
        ..close();

  static double _bez(double p0, double p1, double p2, double p3, double t) {
    final u = 1 - t;
    return u * u * u * p0 +
        3 * u * u * t * p1 +
        3 * u * t * t * p2 +
        t * t * t * p3;
  }
}
