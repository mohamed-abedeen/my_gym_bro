import 'package:flutter/material.dart';

import 'package:my_gym_bro/shared/widgets/glass_decoration.dart';
import 'package:my_gym_bro/shared/widgets/glass_surface.dart';

/// Glass card for session log rows, sets tables.
///
/// Telegram-style frosted glass via [GlassSurface] (real backdrop blur), keeping
/// the original rgba(255,255,255,0.07) fill + soft drop-shadow.
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
  Widget build(BuildContext context) => GlassSurface(
        width: width,
        radius: borderRadius,
        tint: const Color(0x12FFFFFF), // rgba(255,255,255,0.07)
        shadow: GlassDecoration.cardShadow(),
        child: child,
      );
}
