import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/responsive.dart';

/// Glass card for session log rows, sets tables.
///
/// Uses rgba(255,255,255,0.07) background + box-shadow 0 8 40 rgba(0,0,0,0.2).
class GlassCard extends StatelessWidget {

  const GlassCard({
    required this.child,
    this.width,
    this.borderRadius = 24.0,
    super.key,
  });
  final Widget child;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        decoration: BoxDecoration(
          color: const Color(0x12FFFFFF), // rgba(255,255,255,0.07)
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: const Color(0x33000000), // rgba(0,0,0,0.2)
              blurRadius: 40.w,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: child,
      );
}
