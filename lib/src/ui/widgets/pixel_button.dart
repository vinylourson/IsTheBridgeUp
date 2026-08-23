import 'package:flutter/widgets.dart';

import '../theme/palette.dart';
import '../theme/pixel_theme.dart';

/// A hard-edged button that shifts down-right by one pixel-step while held,
/// the way a chunky 8-bit UI control would.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.accent = PixelPalette.open,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final Color accent;
  final bool expand;

  /// Tighter padding and no letter-spacing, so four tab labels fit across a
  /// 320pt screen. Press Start 2P is monospaced at one em per character and
  /// must not be scaled (that would blur it), so the padding gives instead.
  final bool compact;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color border = !enabled
        ? PixelPalette.inkFaint
        : widget.selected
        ? widget.accent
        : PixelPalette.panelBorderBright;
    final Color text = !enabled
        ? PixelPalette.inkFaint
        : widget.selected
        ? PixelPalette.background
        : PixelPalette.ink;
    final Color fill = widget.selected ? widget.accent : PixelPalette.panel;

    final Widget body = Container(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border, width: 2),
      ),
      padding: widget.compact
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 11)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.center,
      child: Text(
        widget.label,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: widget.compact
            ? PixelText.label.copyWith(color: text, letterSpacing: 0)
            : PixelText.label.copyWith(color: text),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: MouseRegion(
          cursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Transform.translate(
            offset: _down ? const Offset(2, 2) : Offset.zero,
            child: widget.expand ? body : IntrinsicWidth(child: body),
          ),
        ),
      ),
    );
  }
}
