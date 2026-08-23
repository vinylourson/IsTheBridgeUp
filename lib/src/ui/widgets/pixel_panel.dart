import 'package:flutter/widgets.dart';

import '../theme/palette.dart';
import '../theme/pixel_theme.dart';

/// A chunky bordered box, optionally with a title strip across the top.
///
/// Borders are drawn as plain rectangles at a whole-pixel width so they stay
/// hard-edged; nothing here is rounded or shadowed.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.title,
    this.borderColor = PixelPalette.panelBorder,
    this.background = PixelPalette.panel,
    this.padding = const EdgeInsets.all(12),
    this.borderWidth = 2,
  });

  final Widget child;
  final String? title;
  final Color borderColor;
  final Color background;
  final EdgeInsetsGeometry padding;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null)
            Container(
              width: double.infinity,
              color: borderColor,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text(
                title!,
                style: PixelText.label.copyWith(color: PixelPalette.background),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
