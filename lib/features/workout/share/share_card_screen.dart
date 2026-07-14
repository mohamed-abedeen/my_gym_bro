import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_exporter.dart';
import 'package:my_gym_bro/features/workout/share/widgets/anatomy_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/editorial_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/hype_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

// ── Screen chrome tokens (design_handoff_share_cards_v2) ──
const _bg = Color(0xFF050506);
const _glassFill = Color(0x12FFFFFF); // white 7%
const _glassBorder = Color(0x1AFFFFFF); // white 10%
const _chipBorder = Color(0x24FFFFFF); // white 14%
const _actionBorder = Color(0x29FFFFFF); // white 16%
const _chipActiveBg = Color(0xFFF4F4F0);

/// Post-workout share sheet: header, a swipeable carousel of the three
/// v2 templates (Editorial / Anatomy / Hype) selected by named chips, the
/// Dark/Sticker background toggle, and the Share / Save / Done action bar.
/// Share captures the currently visible card's [RepaintBoundary] to a PNG
/// and opens the system share sheet; Done (and the top-left X) pop back.
///
/// Each page lives inside its own on-screen [RepaintBoundary] so capturing
/// the visible page is release-safe — `capturePng`'s paint-ready guard is
/// debug-only, so the card being snapshotted must already be mounted+painted.
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({required this.data, super.key});

  final ShareCardData data;

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _controller = PageController();
  final _shareBtnKey = GlobalKey();
  late final List<Widget> _cards;
  late final List<GlobalKey> _boundaryKeys;
  int _page = 0;

  /// The raster-precache future, awaited before the first capture so the base
  /// anatomy PNG + brand logo + rank badge are decoded in the snapshot.
  Future<void>? _precache;

  @override
  void initState() {
    super.initState();
    final data = widget.data;
    _cards = [
      EditorialShareCard(data: data),
      AnatomyShareCard(data: data),
      HypeShareCard(data: data),
    ];
    _boundaryKeys = [for (var i = 0; i < _cards.length; i++) GlobalKey()];

    // Precache the anatomy/skin + logo + rank rasters so the first capture
    // isn't a half-loaded frame. Deferred to post-frame so `context` can
    // resolve the image configuration (MediaQuery etc.).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precache = ShareCardExporter.precacheCardImages(
        context,
        basePngPath: ref.read(activeSkinPathProvider),
        rank: ref.read(myRankProvider),
      );
      unawaited(_precache);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The Share button's global rect — the iPad share popover anchors to it.
  /// Read before any `await` so the render object is still attached.
  Rect? _shareButtonRect() {
    final box = _shareBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Settles the visible card's async rasters, then snapshots it to PNG.
  /// Returns null on any failure (render tree changed, encoding failed) so the
  /// caller can show its own error SnackBar. Used by both Share and Save.
  Future<Uint8List?> _captureCurrent() async {
    try {
      // Make sure the card's async rasters are settled before snapshotting:
      // (1) await the base PNG + logo + rank-badge precache; (2) settle two
      // frames so the flutter_svg muscle overlays have decoded+painted (they
      // have no precache hook). The card is on-screen so these are usually
      // already done — this just closes the "tap the instant a page appears"
      // race that would otherwise capture a body with missing highlights.
      // ponytail: frame-settle over a flutter_svg cache-warm — simpler and
      // version-robust; add explicit SVG precache only if artifacts appear.
      if (_precache != null) await _precache;
      if (!mounted) return null;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      return await ShareCardExporter.capturePng(_boundaryKeys[_page]);
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    // Read the popover anchor before any await, while the render object is
    // still attached.
    final rect = _shareButtonRect();
    final bytes = await _captureCurrent();
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareError)),
      );
      return;
    }
    try {
      await ShareCardExporter.shareImage(bytes, sharePositionOrigin: rect);
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareError)),
      );
    }
  }

  /// Saves the currently visible card's PNG to the device photo gallery.
  /// Works in both Dark and Sticker mode (sticker saves real alpha). `gal`
  /// prompts for library access itself and throws [GalException] if it's
  /// denied — caught here so a denial shows a SnackBar instead of crashing.
  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final bytes = await _captureCurrent();
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareSaveError)),
      );
      return;
    }
    try {
      await Gal.putImageBytes(bytes, album: 'My Gym Bro');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareSaved)),
      );
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareSaveError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = widget.data;
    final transparent = ref.watch(shareCardTransparentProvider);
    final templateNames = [
      l10n.shareTemplateEditorial,
      l10n.shareTemplateAnatomy,
      l10n.shareTemplateHype,
    ];
    final subtitle = [
      data.workoutName.toUpperCase(),
      if (data.workoutNumber > 0)
        l10n.shareWorkoutNumber(data.workoutNumber).toUpperCase(),
    ].join(' · ');

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: glass X · "Nice work." · workout subline ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  _GlassCloseButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.shareNiceWork,
                          style: shareArchivo(
                            22,
                            weight: 800,
                            width: 110,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: shareMono(11, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Carousel of the 3 templates ──
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _cards.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 34,
                      vertical: 12,
                    ),
                    child: Stack(
                      children: [
                        // Sticker-mode preview: a checkerboard BEHIND the
                        // boundary (never captured) so the user sees the alpha.
                        if (transparent)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: const CustomPaint(
                                painter: _CheckerPainter(),
                              ),
                            ),
                          ),
                        RepaintBoundary(
                          key: _boundaryKeys[i],
                          child: _cards[i],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Named template chips ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              // FittedBox: long localized names shrink instead of overflowing.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < templateNames.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _TemplateChip(
                        key: Key('share_chip_$i'),
                        label: templateNames[i],
                        active: i == _page,
                        onTap: () => _controller.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Dark / Sticker background toggle ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              child: _StyleToggle(
                transparent: transparent,
                onChanged: (v) =>
                    ref.read(shareCardTransparentProvider.notifier).state = v,
                l10n: l10n,
              ),
            ),

            // ── Actions: Share (wide primary) · Save · Done ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: _shareBtnKey,
                      onPressed: () => unawaited(_share()),
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
                        onPressed: () => unawaited(_save()),
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
                    onPressed: () => Navigator.of(context).pop(),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 40px circular translucent close button in the header.
class _GlassCloseButton extends StatelessWidget {
  const _GlassCloseButton({required this.onTap});

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

/// One named template chip: filled off-white when active, hairline outline
/// otherwise.
class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _chipActiveBg : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: active ? Colors.transparent : _chipBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF000000) : kShareTextSecondary,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The Dark / Sticker segmented toggle above the action bar.
class _StyleToggle extends StatelessWidget {
  const _StyleToggle({
    required this.transparent,
    required this.onChanged,
    required this.l10n,
  });

  final bool transparent;
  final ValueChanged<bool> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
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

/// A simple two-tone checkerboard — the sticker-mode preview backdrop that
/// reveals the card's alpha. Painted BEHIND the RepaintBoundary, so it is
/// never part of the exported PNG.
class _CheckerPainter extends CustomPainter {
  const _CheckerPainter();

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
  bool shouldRepaint(_CheckerPainter oldDelegate) => false;
}
