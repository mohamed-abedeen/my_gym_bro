import 'dart:ui';

import 'package:flutter/material.dart';

import '../responsive.dart';

/// Scroll edge effect applied to ALL sheet screens.
///
/// Creates a frosted glass fade where scrolled content passes under the header,
/// matching the Figma "Scroll Edge Effect" layers.
class ScrollEdgeEffect extends StatelessWidget {
  final Widget child;

  const ScrollEdgeEffect({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Hard blur: h:118pt — scrolled content blurs here
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 118.h,
          child: IgnorePointer(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xE6000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Soft blur: h:69pt — very top
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 69.h,
          child: IgnorePointer(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
