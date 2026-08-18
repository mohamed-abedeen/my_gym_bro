import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The brand streak-fire icon (full-color SVG) — replaces the 🔥 emoji
/// everywhere a streak is rendered in the UI. Notification copy keeps the
/// emoji (plain strings can't embed an SVG).
class FireIcon extends StatelessWidget {
  const FireIcon({required this.size, super.key});

  /// Rendered width/height — pass the font size the emoji used so the icon
  /// occupies the same slot.
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/icons/fire.svg', width: size, height: size);
}
