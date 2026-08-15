import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import 'package:my_gym_bro/features/leaderboard/leaderboard_providers.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:my_gym_bro/features/settings/skin_provider.dart';
import 'package:my_gym_bro/features/workout/share/exercise_share_data.dart';
import 'package:my_gym_bro/features/workout/share/share_exporter.dart';
import 'package:my_gym_bro/features/workout/share/share_screen_chrome.dart';
import 'package:my_gym_bro/features/workout/share/widgets/exercise_share_card.dart';
import 'package:my_gym_bro/features/workout/share/widgets/share_card_widgets.dart';
import 'package:my_gym_bro/l10n/app_localizations.dart';

const _bg = Color(0xFF050506);

/// Exercise share sheet — the single exercise template plus the same chrome
/// as the session share screen (Dark/Sticker toggle, Share / Save / Done).
/// Opened from the exercise detail screen with a prebuilt
/// [ExerciseShareData]; capture follows the session screen's release-safe
/// pattern (the card lives in an on-screen [RepaintBoundary], rasters are
/// precached, two frames settle before the snapshot).
class ExerciseShareScreen extends ConsumerStatefulWidget {
  const ExerciseShareScreen({required this.data, super.key});

  final ExerciseShareData data;

  @override
  ConsumerState<ExerciseShareScreen> createState() =>
      _ExerciseShareScreenState();
}

class _ExerciseShareScreenState extends ConsumerState<ExerciseShareScreen> {
  final _shareBtnKey = GlobalKey();
  final _boundaryKey = GlobalKey();

  /// The raster-precache future, awaited before the first capture so the
  /// brand logo + rank badge are decoded in the snapshot.
  Future<void>? _precache;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final band = widget.data.rankBand;
      _precache = ShareCardExporter.precacheCardImages(
        context,
        basePngPath: ref.read(activeSkinPathProvider),
        rank: ref.read(myRankProvider),
        liftRanks: [if (band != null) Rank.fromBand(band)],
      );
      unawaited(_precache);
    });
  }

  /// The Share button's global rect — the iPad share popover anchors to it.
  /// Read before any `await` so the render object is still attached.
  Rect? _shareButtonRect() {
    final box = _shareBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Settles the card's async rasters, then snapshots it to PNG. Returns null
  /// on any failure so the caller shows its own error SnackBar.
  Future<Uint8List?> _capture() async {
    try {
      if (_precache != null) await _precache;
      if (!mounted) return null;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return null;
      return await ShareCardExporter.capturePng(_boundaryKey);
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    // Read the popover anchor before any await, while the render object is
    // still attached.
    final rect = _shareButtonRect();
    final bytes = await _capture();
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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final bytes = await _capture();
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
    final transparent = ref.watch(shareCardTransparentProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: glass X · "Your progress." · exercise subline ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  ShareGlassCloseButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.shareExerciseTitle,
                          style: shareArchivo(
                            22,
                            weight: 800,
                            width: 110,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.data.exerciseName.toUpperCase(),
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

            // ── The single exercise card ──
            Expanded(
              child: Center(
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
                              painter: ShareCheckerPainter(),
                            ),
                          ),
                        ),
                      RepaintBoundary(
                        key: _boundaryKey,
                        child: ExerciseShareCard(data: widget.data),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Dark / Sticker background toggle ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
              child: ShareStyleToggle(
                transparent: transparent,
                onChanged: (v) =>
                    ref.read(shareCardTransparentProvider.notifier).state = v,
              ),
            ),

            // ── Actions: Share (wide primary) · Save · Done ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ShareActionBar(
                shareButtonKey: _shareBtnKey,
                onShare: () => unawaited(_share()),
                onSave: () => unawaited(_save()),
                onDone: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
