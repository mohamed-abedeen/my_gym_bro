import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';

/// Shared chrome every share-card template wraps its body in: a 9:16 rounded
/// canvas holding a fixed 405×720 design space (the handoff's card size),
/// uniformly scaled to whatever size the carousel gives it — so the templates
/// lay out in absolute design pixels and stay pixel-faithful at any size.
///
/// Sticker mode ([shareCardTransparentProvider]) drops the background fill so
/// the exported PNG keeps real alpha; content is unaffected.
class ShareCardFrame extends ConsumerWidget {
  const ShareCardFrame({required this.child, this.color, this.gradient, super.key});

  final Widget child;

  /// Flat background; defaults to [kShareCardBg]. Ignored when [gradient] is
  /// set, and both are ignored in sticker mode.
  final Color? color;
  final Gradient? gradient;

  /// The handoff's card canvas — templates position in these coordinates.
  static const designSize = Size(405, 720);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transparent = ref.watch(shareCardTransparentProvider);
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: FittedBox(
          child: SizedBox.fromSize(
            size: designSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: transparent || gradient != null
                    ? null
                    : (color ?? kShareCardBg),
                gradient: transparent ? null : gradient,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
