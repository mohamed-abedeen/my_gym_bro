import 'package:flutter/material.dart';

import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

/// Chrome shared by the share screens (session `ShareCardScreen`, exercise
/// `ExerciseShareScreen`): the glass close button, the Dark/Sticker toggle,
/// the sticker-preview checkerboard, and the Share/Save/Done action bar.
/// Extracted verbatim from `share_card_screen.dart` so both screens stay
/// pixel-identical (design_handoff_share_cards_v2 tokens).

const _glassFill = Color(0x12FFFFFF); // white 7%
const _glassBorder = Color(0x1AFFFFFF); // white 10%
const _actionBorder = Color(0x29FFFFFF); // white 16%

/// The 40px circular translucent close button in the header.
class ShareGlassCloseButton extends StatelessWidget {
  const ShareGlassCloseButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _glassFill,
      shape: const CircleBorder(side: BorderSide(color: _glassBorder)),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: kShareTextPrimary,
            semanticLabel:
                MaterialLocalizations.of(context).closeButtonTooltip,
          ),
        ),
      ),
    );
  }
}

/// The Dark / Sticker segmented toggle above the action bar.
class ShareStyleToggle extends StatelessWidget {
  const ShareStyleToggle({
    required this.transparent,
    required this.onChanged,
    super.key,
  });

  final bool transparent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0x0FFFFFFF), // white 6%
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _segment(
                l10n.shareStyleDark,
                !transparent,
                () => onChanged(false),
              ),
              const SizedBox(width: 2),
              _segment(
                l10n.shareStyleSticker,
                transparent,
                () => onChanged(true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0x24FFFFFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? kShareTextPrimary : kShareTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Actions row: Share (wide primary) · Save (circular icon) · Done (pill).
/// [shareButtonKey] marks the Share button so callers can read its global
/// rect for the iPad share-popover anchor.
class ShareActionBar extends StatelessWidget {
  const ShareActionBar({
    required this.shareButtonKey,
    required this.onShare,
    required this.onSave,
    required this.onDone,
    super.key,
  });

  final GlobalKey shareButtonKey;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: shareButtonKey,
            onPressed: onShare,
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            label: Text(l10n.share),
            style: FilledButton.styleFrom(
              backgroundColor: kShareAccent,
              foregroundColor: const Color(0xFF000000),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Save — icon-only circular button.
        Tooltip(
          message: l10n.save,
          child: SizedBox(
            width: 56,
            height: 56,
            child: OutlinedButton(
              key: const Key('share_save_btn'),
              onPressed: onSave,
              style: OutlinedButton.styleFrom(
                foregroundColor: kShareTextPrimary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(56, 56),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: _actionBorder),
                shape: const CircleBorder(),
              ),
              child: const Icon(
                Icons.file_download_outlined,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Done — compact outlined pill.
        OutlinedButton(
          onPressed: onDone,
          style: OutlinedButton.styleFrom(
            foregroundColor: kShareTextPrimary,
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            side: const BorderSide(color: _actionBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(l10n.done),
        ),
      ],
    );
  }
}

/// A simple two-tone checkerboard — the sticker-mode preview backdrop that
/// reveals the card's alpha. Painted BEHIND the RepaintBoundary, so it is
/// never part of the exported PNG.
class ShareCheckerPainter extends CustomPainter {
  const ShareCheckerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 15.0;
    final light = Paint()..color = const Color(0xFF33343A);
    final dark = Paint()..color = const Color(0xFF25262B);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final even = ((x ~/ cell) + (y ~/ cell)).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, cell, cell),
          even ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ShareCheckerPainter oldDelegate) => false;
}
