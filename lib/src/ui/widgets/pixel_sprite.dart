import 'package:flutter/widgets.dart';

import '../theme/palette.dart';

/// A horizontal run of same-coloured pixels, so the painter issues one
/// drawRect per run instead of one per pixel.
class _Run {
  const _Run(this.x, this.y, this.length, this.color);
  final int x;
  final int y;
  final int length;
  final Color color;
}

/// A sprite matrix compiled into draw-ready runs.
///
/// Parsing is done once per matrix and cached: the matrices are `const`, so
/// identity makes a perfectly good cache key.
class PixelMatrix {
  PixelMatrix._(this.width, this.height, this._runs);

  factory PixelMatrix.of(List<String> rows) =>
      _cache[rows] ??= PixelMatrix._compile(rows);

  factory PixelMatrix._compile(List<String> rows) {
    assert(rows.isNotEmpty, 'sprite matrix must have at least one row');
    final int height = rows.length;
    final int width = rows.first.length;
    assert(
      rows.every((String r) => r.length == width),
      'sprite matrix rows must all be the same width',
    );

    final List<_Run> runs = <_Run>[];
    for (int y = 0; y < height; y++) {
      final String row = rows[y];
      int x = 0;
      while (x < width) {
        final String ch = row[x];
        if (ch == '.') {
          x++;
          continue;
        }
        final Color? color = PixelPalette.charToColor[ch];
        assert(color != null, 'sprite uses unmapped character "$ch"');
        int run = 1;
        while (x + run < width && row[x + run] == ch) {
          run++;
        }
        runs.add(_Run(x, y, run, color!));
        x += run;
      }
    }
    return PixelMatrix._(width, height, runs);
  }

  static final Map<List<String>, PixelMatrix> _cache =
      <List<String>, PixelMatrix>{};

  final int width;
  final int height;
  final List<_Run> _runs;

  double get aspectRatio => width / height;

  /// Paints the sprite with its top-left at [origin], each source pixel
  /// becoming a [pixel]-sized square. [flip] mirrors it horizontally.
  void paint(
    Canvas canvas,
    Offset origin,
    double pixel, {
    bool flip = false,
    double opacity = 1,
  }) {
    final Paint paint = Paint()..isAntiAlias = false;
    for (final _Run run in _runs) {
      final int startX = flip ? width - run.x - run.length : run.x;
      paint.color = opacity >= 1
          ? run.color
          : run.color.withValues(alpha: run.color.a * opacity);
      canvas.drawRect(
        Rect.fromLTWH(
          origin.dx + startX * pixel,
          origin.dy + run.y * pixel,
          run.length * pixel,
          pixel,
        ),
        paint,
      );
    }
  }
}

/// Draws a pixel-art sprite at a whole-number scale so it never blurs.
class PixelSprite extends StatelessWidget {
  const PixelSprite(
    this.rows, {
    super.key,
    this.scale,
    this.targetHeight,
    this.flip = false,
    this.semanticLabel,
  }) : assert(
         scale == null || targetHeight == null,
         'give either scale or targetHeight, not both',
       );

  final List<String> rows;

  /// Exact pixel size of one sprite pixel.
  final double? scale;

  /// Desired height; the scale is floored to a whole number so edges stay
  /// hard, which is the whole point of pixel art.
  final double? targetHeight;

  final bool flip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final PixelMatrix matrix = PixelMatrix.of(rows);
    final double resolved = switch ((scale, targetHeight)) {
      (final double s?, _) => s,
      (_, final double h?) => (h / matrix.height).floorToDouble().clamp(1, 64),
      _ => 2,
    };

    Widget sprite = CustomPaint(
      size: Size(matrix.width * resolved, matrix.height * resolved),
      painter: _SpritePainter(matrix, resolved, flip),
      isComplex: false,
    );
    if (semanticLabel != null) {
      sprite = Semantics(label: semanticLabel, image: true, child: sprite);
    }
    return sprite;
  }
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter(this.matrix, this.pixel, this.flip);

  final PixelMatrix matrix;
  final double pixel;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) =>
      matrix.paint(canvas, Offset.zero, pixel, flip: flip);

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.matrix != matrix || old.pixel != pixel || old.flip != flip;
}
