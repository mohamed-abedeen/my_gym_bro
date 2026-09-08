import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dashed rounded outline — Flutter's [Border] has no dashed style.
///
/// Reads as a placeholder / "add" affordance: the weekly-plan "Add rest day"
/// row and the Discover "Create your own" card both outline themselves with it.
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });
  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    // Inset half the stroke so the line isn't clipped at the edges.
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}
