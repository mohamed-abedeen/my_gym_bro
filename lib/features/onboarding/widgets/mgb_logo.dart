import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:my_gym_bro/shared/constants.dart';

/// The MGB logo mark from the handoff (`logo_mgb.svg`), one path per letter
/// so the splash can slam them in one at a time. Fills are inline — flutter_svg
/// ignores `<style>` blocks.
class MgbLogo extends StatelessWidget {
  const MgbLogo({
    required this.size,
    this.letterScale = const [1, 1, 1],
    this.letterOpacity = const [1, 1, 1],
    super.key,
  });

  final double size;

  /// Per-letter scale (M, G, B), each about its own centre.
  final List<double> letterScale;
  final List<double> letterOpacity;

  static const _viewBox = 1000.0;

  /// Path data + each letter's bounding-box centre in the 1000-unit viewBox.
  /// (Chunks end in a space — SVG path data allows whitespace between
  /// numbers, and no chunk splits one.)
  static const _letters = [
    (
      'M187.5,321.88l15.83,33.38-16.13-86.01h97.97l17.03,167.53-24.19,81.52, '
          '94.68-249.05h88.41l-69.3,408.88-15.83-33.38,16.13,86.01h-89.01 '
          'l36.14-213.1-76.46,213.1h-24.19l-3.58-219.52-28.08,166.89 '
          '-15.83-33.38,16.13,86.01h-89.01l69.3-408.87Z',
      Offset(289.66, 500),
    ),
    (
      'M609.54,664.64l-41.82,66.11h-134.71l-19.71-66.11,58.24-342.76, '
          '15.83,33.38-16.13-86.01h174.73l19.41,66.12-12.25,72.530 '
          '-85.43,32.73,12.54-72.53h-37.04l-41.22,243.91-21.48,19.9h54.93 '
          'l10.45-62.26h-16.54l27.3-98.85h85.72l-32.86,193.85Z',
      Offset(539.34, 500),
    ),
    (
      'M819.51,453.46l18.82,8.99,12.84,34.02-32.58,191.07-37.91,43.22 '
          'h-165.47l69.3-408.87,15.83,33.38-16.13-86.01h174.73l22.85,45.5 '
          '-10.61,63.62-51.67,75.1ZM748.42,631.9l19.41-114.9-52.87,95-22,19.9 '
          'h55.45ZM784.18,374.94l-27.99-6.84-17.03,101.42,51.08-84.73 '
          '-6.06-9.85Z',
      Offset(748.5, 500),
    ),
  ];

  static String _svg(String path) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000"> '
      '<path fill="#EDEDED" d="$path"/></svg>';

  @override
  Widget build(BuildContext context) {
    final k = size / _viewBox;
    return Semantics(
      label: 'My Gym Bro',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            for (final (i, (path, centre)) in _letters.indexed)
              Positioned.fill(
                child: Opacity(
                  opacity: letterOpacity[i].clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: letterScale[i],
                    origin: Offset(
                      (centre.dx - _viewBox / 2) * k,
                      (centre.dy - _viewBox / 2) * k,
                    ),
                    child: SvgPicture.string(
                      _svg(path),
                      width: size,
                      height: size,
                      colorFilter: const ColorFilter.mode(
                        AppOnboarding.textLogo,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
