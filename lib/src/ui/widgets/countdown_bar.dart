import 'package:flutter/widgets.dart';

import '../theme/palette.dart';

/// A chunky segmented progress bar: filled cells, then hollow ones.
///
/// Segments rather than a smooth bar, because a continuous gradient would
/// look out of place next to bitmap type.
class CountdownBar extends StatelessWidget {
  const CountdownBar({
    super.key,
    required this.progress,
    this.segments = 20,
    this.color = PixelPalette.open,
    this.emptyColor = PixelPalette.inkFaint,
    this.height = 14,
    this.semanticLabel,
  });

  /// 0 = nothing elapsed, 1 = complete. Values outside are clamped.
  final double progress;
  final int segments;
  final Color color;
  final Color emptyColor;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final double clamped = progress.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _CountdownPainter(
            progress: clamped,
            segments: segments,
            color: color,
            emptyColor: emptyColor,
          ),
        ),
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  const _CountdownPainter({
    required this.progress,
    required this.segments,
    required this.color,
    required this.emptyColor,
  });

  final double progress;
  final int segments;
  final Color color;
  final Color emptyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..isAntiAlias = false;
    const double gap = 2;
    final double cell = (size.width - gap * (segments - 1)) / segments;
    // Round up so any progress at all lights the first cell.
    final int filled = (progress * segments).ceil().clamp(
      progress > 0 ? 1 : 0,
      segments,
    );

    for (int i = 0; i < segments; i++) {
      paint.color = i < filled ? color : emptyColor;
      final Rect rect = Rect.fromLTWH(
        i * (cell + gap),
        i < filled ? 0 : size.height * 0.25,
        cell,
        i < filled ? size.height : size.height * 0.5,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_CountdownPainter old) =>
      old.progress != progress ||
      old.segments != segments ||
      old.color != color ||
      old.emptyColor != emptyColor;
}
