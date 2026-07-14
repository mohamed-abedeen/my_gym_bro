import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:my_gym_bro/features/leaderboard/rank.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Captures a widget wrapped in a [RepaintBoundary] to a PNG and shares it.
///
/// Usage: wrap the card in `RepaintBoundary(key: boundaryKey, child: card)`,
/// [precacheCardImages] before the first capture, then [capturePng] /
/// [shareImage].
abstract final class ShareCardExporter {
  /// Snapshots the [RenderRepaintBoundary] behind [boundaryKey] to PNG bytes.
  ///
  /// [pixelRatio] scales the raster (3.0 ≈ retina-crisp for a phone-sized
  /// card). Waits a frame when the boundary hasn't painted yet so the PNG
  /// isn't blank. `debugNeedsPaint` is debug-only (it throws in release), so
  /// it is probed inside an assert; callers must capture only after the card
  /// is mounted and its images are precached.
  static Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3.0,
  }) async {
    final object = boundaryKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      throw StateError(
        'capturePng: key is not attached to a RenderRepaintBoundary',
      );
    }

    var needsFrame = false;
    assert(() {
      needsFrame = object.debugNeedsPaint;
      return true;
    }(), 'probe paint state in debug only');
    if (needsFrame) {
      await WidgetsBinding.instance.endOfFrame;
    }

    final image = await object.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('capturePng: PNG encoding returned null');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Writes [bytes] to a fixed temp file (overwritten each call) and returns
  /// it as an [XFile]. The stable name keeps the temp dir from filling up.
  static Future<XFile> writeTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/mygymbro_share.png');
    await file.writeAsBytes(bytes, flush: true);
    return XFile(file.path, mimeType: 'image/png');
  }

  /// Writes the PNG to temp and opens the system share sheet.
  ///
  /// Pass [sharePositionOrigin] (the share button's global rect) on iPad so
  /// the share popover has an anchor.
  static Future<void> shareImage(
    Uint8List bytes, {
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    final file = await writeTempPng(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Precaches the raster assets a card needs so [capturePng] doesn't snapshot
  /// a half-loaded frame: the base anatomy/skin PNG, the brand logo, and the
  /// rank badge PNG.
  ///
  /// The anatomy muscle overlays are SVGs loaded async by `flutter_svg`; they
  /// have no simple precache hook, so mount the card off-screen and give it a
  /// frame or two to settle before capturing.
  static Future<void> precacheCardImages(
    BuildContext context, {
    required String basePngPath,
    Rank? rank,
  }) async {
    await precacheImage(AssetImage(basePngPath), context);
    if (!context.mounted) return;
    await precacheImage(const AssetImage('assets/images/mgb_icon.png'), context);
    if (rank != null && context.mounted) {
      try {
        await precacheImage(AssetImage(rank.assetPath), context);
      } on Exception {
        // Badge art not shipped for this tier yet — RankBadge renders its
        // vector fallback, which needs no precache.
      }
    }
  }
}
