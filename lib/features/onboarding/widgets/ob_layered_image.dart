import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A base image with overlay layers composited in one canvas, so the
/// overlays can use a real [BlendMode] against the base (the female body
/// maps use `mix-blend-mode: screen`, which keeps the render's shading
/// visible through the color). Layer opacity changes animate over
/// [duration].
class ObLayeredImage extends StatefulWidget {
  const ObLayeredImage({
    required this.base,
    required this.layers,
    required this.opacities,
    this.blendMode = BlendMode.srcOver,
    this.duration = const Duration(milliseconds: 600),
    super.key,
  }) : assert(layers.length == opacities.length, 'one opacity per layer');

  final String base;
  final List<String> layers;
  final List<double> opacities;
  final BlendMode blendMode;
  final Duration duration;

  @override
  State<ObLayeredImage> createState() => _ObLayeredImageState();
}

class _ObLayeredImageState extends State<ObLayeredImage>
    with SingleTickerProviderStateMixin {
  final Map<String, ui.Image> _images = {};
  final List<(ImageStream, ImageStreamListener)> _streams = [];
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: widget.duration)..value = 1;
  late List<double> _from = [...widget.opacities];
  late List<double> _to = [...widget.opacities];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_streams.isNotEmpty) return;
    final config = createLocalImageConfiguration(context);
    for (final asset in [widget.base, ...widget.layers]) {
      final stream = AssetImage(asset).resolve(config);
      // Each listener owns (and must dispose) the image clone it receives.
      final listener = ImageStreamListener((info, _) {
        if (!mounted) {
          info.dispose();
          return;
        }
        setState(() {
          _images[asset]?.dispose();
          _images[asset] = info.image;
        });
      });
      stream.addListener(listener);
      _streams.add((stream, listener));
    }
  }

  @override
  void didUpdateWidget(ObLayeredImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    var changed = false;
    for (var i = 0; i < widget.opacities.length; i++) {
      if (widget.opacities[i] != _to[i]) changed = true;
    }
    if (!changed) return;
    _from = _current();
    _to = [...widget.opacities];
    _fade.forward(from: 0);
  }

  List<double> _current() {
    final t = Curves.ease.transform(_fade.value);
    return [
      for (var i = 0; i < _to.length; i++) _from[i] + (_to[i] - _from[i]) * t,
    ];
  }

  @override
  void dispose() {
    _fade.dispose();
    for (final (stream, listener) in _streams) {
      stream.removeListener(listener);
    }
    for (final image in _images.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _LayersPainter(
          base: _images[widget.base],
          layers: [for (final l in widget.layers) _images[l]],
          opacities: _current(),
          blendMode: widget.blendMode,
        ),
      ),
    );
  }
}

class _LayersPainter extends CustomPainter {
  _LayersPainter({
    required this.base,
    required this.layers,
    required this.opacities,
    required this.blendMode,
  });

  final ui.Image? base;
  final List<ui.Image?> layers;
  final List<double> opacities;
  final BlendMode blendMode;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    void draw(ui.Image image, Paint paint) {
      final src = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      canvas.drawImageRect(image, src, dst, paint);
    }

    final b = base;
    if (b == null) return;
    // Isolate the stack so blend modes only see the base, not the page.
    canvas.saveLayer(dst, Paint());
    draw(b, Paint()..filterQuality = FilterQuality.medium);
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final o = opacities[i].clamp(0.0, 1.0);
      if (layer == null || o <= 0) continue;
      draw(
        layer,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..blendMode = blendMode
          ..color = Color.fromRGBO(0, 0, 0, o),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LayersPainter old) =>
      old.base != base ||
      old.blendMode != blendMode ||
      !_listEquals(old.layers, layers) ||
      !_listEquals(old.opacities, opacities);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
