import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/share/share_card_data.dart';
import 'package:my_gym_bro/features/workout/share/share_exporter.dart';
import 'package:my_gym_bro/features/workout/share/widgets/exercise_list_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/hero_stats_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/features/workout/share/widgets/stat_stack_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/volume_hype_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/weekly_progress_card.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';
import 'package:my_gym_bro/shared/constants.dart';

/// Post-workout share sheet: a full-screen dark canvas with a swipeable
/// carousel of the five share-card templates. Share captures the currently
/// visible card's [RepaintBoundary] to a PNG and opens the system share sheet;
/// Done (and the top-left X) pop back to home.
///
/// Each page lives inside its own on-screen [RepaintBoundary] so capturing the
/// visible page is release-safe — `capturePng`'s paint-ready guard is
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
  /// anatomy PNG + rank badge are decoded (not transparent) in the snapshot.
  Future<void>? _precache;

  @override
  void initState() {
    super.initState();
    final data = widget.data;
    _cards = [
      HeroStatsCard(data: data),
      WeeklyProgressCard(data: data),
      ExerciseListCard(data: data),
      VolumeHypeCard(data: data),
      StatStackCard(data: data),
    ];
    _boundaryKeys = [for (var i = 0; i < _cards.length; i++) GlobalKey()];

    // Precache the anatomy/skin + rank rasters so the first capture isn't a
    // half-loaded frame. Deferred to post-frame so `context` can resolve the
    // image configuration (MediaQuery etc.).
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
      // (1) await the base PNG + rank-badge precache; (2) settle two frames so
      // the flutter_svg muscle overlays have decoded+painted (they have no
      // precache hook). The card is on-screen so these are usually already
      // done — this just closes the "tap the instant a page appears" race
      // that would otherwise capture a body with missing muscle highlights.
      // ponytail: frame-settle over a flutter_svg cache-warm — simpler and
      // version-robust; add explicit SVG precache only if artifacts appear.
      if (_precache != null) await _precache;
      if (!mounted) return null;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      return await ShareCardExporter.capturePng(_boundaryKeys[_page]);
    } catch (_) {
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.shareError)),
      );
    }
  }

  /// Saves the currently visible card's PNG to the device photo gallery.
  /// Works in both Normal and Transparent mode (transparent saves real alpha).
  /// `gal` prompts for library access itself and throws [GalException] if it's
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
    } catch (_) {
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

    // Shared dark-outlined style for the two secondary actions (Save + Done).
    final outlinedStyle = OutlinedButton.styleFrom(
      foregroundColor: kShareTextPrimary,
      minimumSize: const Size.fromHeight(54),
      side: BorderSide(color: kShareTextSecondary.withValues(alpha: 0.5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: X + "Nice work!" + optional "Workout #N" ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: kShareTextPrimary,
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.shareNiceWork, style: shareTitleStyle(size: 24)),
                        if (data.workoutNumber > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.shareWorkoutNumber(data.workoutNumber),
                            style: shareLabelStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 40), // balance the leading X
                ],
              ),
            ),

            // ── Carousel of the 5 templates ──
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _cards.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Stack(
                      children: [
                        // Transparent-mode preview: a checkerboard BEHIND the
                        // boundary (never captured) so the user sees the alpha.
                        if (transparent)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.card),
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

            // ── Normal / Transparent style toggle ──
            _StyleToggle(
              transparent: transparent,
              onChanged: (v) =>
                  ref.read(shareCardTransparentProvider.notifier).state = v,
              l10n: l10n,
            ),

            // ── Page dots ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _cards.length; i++)
                    AnimatedContainer(
                      key: Key('share_dot_$i'),
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: i == _page ? 18 : 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? kShareAccent
                            : kShareTextSecondary.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),

            // ── Actions: Share (wide primary) + Save + Done ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: _shareBtnKey,
                      onPressed: () => unawaited(_share()),
                      style: FilledButton.styleFrom(
                        backgroundColor: kShareAccent,
                        foregroundColor: const Color(0xFF000000),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(l10n.share),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => unawaited(_save()),
                      style: outlinedStyle,
                      child: Text(l10n.save),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: outlinedStyle,
                      child: Text(l10n.done),
                    ),
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

/// The Normal / Transparent segmented toggle above the page dots.
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _segment(l10n.shareStyleNormal, !transparent, () => onChanged(false)),
          _segment(
            l10n.shareStyleTransparent,
            transparent,
            () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? kShareAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? const Color(0xFF000000) : kShareTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// A simple two-tone checkerboard — the transparent-mode preview backdrop that
/// reveals the card's alpha. Painted BEHIND the RepaintBoundary, so it is never
/// part of the exported PNG.
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
