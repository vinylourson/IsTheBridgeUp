import 'package:flutter/widgets.dart';

import '../theme/palette.dart';
import '../theme/pixel_theme.dart';

/// A one-line banner for staleness and refresh failures.
class NoticeStrip extends StatelessWidget {
  const NoticeStrip({
    super.key,
    required this.message,
    this.color = PixelPalette.warning,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
      child: Text(
        message,
        style: PixelText.bodySmall.copyWith(color: color),
      ),
    );
  }
}
