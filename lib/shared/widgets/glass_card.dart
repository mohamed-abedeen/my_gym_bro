import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';

/// Glass card for session log rows, sets tables.
///
/// Uses rgba(255,255,255,0.07) background + a soft drop-shadow shared with
/// the other frosted-glass surfaces (see [GlassDecoration]).
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
          boxShadow: [GlassDecoration.cardShadow()],
        ),
        child: child,
      );
}
