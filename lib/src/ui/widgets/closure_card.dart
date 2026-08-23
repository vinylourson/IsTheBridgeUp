import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations.dart';
import '../../domain/models/closure.dart';
import '../format.dart';
import '../theme/palette.dart';
import '../theme/pixel_sprites.dart';
import '../theme/pixel_theme.dart';
import 'pixel_sprite.dart';

/// One closure as a row: when, for how long, and what is passing.
class ClosureCard extends StatelessWidget {
  const ClosureCard({
    super.key,
    required this.closure,
    required this.now,
    this.highlight = false,
  });

  final Closure closure;
  final tz.TZDateTime now;

  /// Draws attention to the closure currently in progress.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final bool inProgress = closure.contains(now);
    final Color accent = inProgress || highlight
        ? PixelPalette.closed
        : PixelPalette.panelBorderBright;

    return Container(
      decoration: BoxDecoration(
        color: PixelPalette.panel,
        border: Border.all(color: accent, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: PixelSprite(
              closure.isMaintenance
                  ? PixelSprites.cone
                  : PixelSprites.ship,
              scale: closure.isMaintenance ? 2 : 1,
              semanticLabel: closure.isMaintenance
                  ? l10n.maintenanceLabel
                  : closure.vesselLabel,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        Fmt.day(l10n, locale, closure.start, now),
                        style: PixelText.label.copyWith(
                          color: PixelPalette.inkDim,
                        ),
                      ),
                    ),
                    if (inProgress)
                      Text(
                        l10n.inProgress,
                        style: PixelText.label.copyWith(
                          color: PixelPalette.closed,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.closureWindow(
                    Fmt.time(locale, closure.start),
                    Fmt.time(locale, closure.end),
                  ),
                  style: PixelText.data,
                ),
                const SizedBox(height: 4),
                Text(
                  closure.isMaintenance
                      ? l10n.maintenanceLabel
                      : closure.vessels.join(' · '),
                  style: PixelText.bodySmall.copyWith(
                    color: PixelPalette.inkDim,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  <String>[
                    l10n.durationLabel(Fmt.duration(l10n, closure.duration)),
                    if (closure.isOvernight) l10n.overnightNote,
                  ].join(' · '),
                  style: PixelText.bodySmall.copyWith(
                    color: PixelPalette.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
