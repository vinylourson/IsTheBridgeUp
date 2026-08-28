import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../data/services/home_widget_service.dart';
import '../domain/models/bridge_status.dart';
import '../domain/models/closure.dart';
import 'format.dart';

/// Builds what the home-screen widget should show.
///
/// Pure, and separate from the shell that calls it, so the strings the widget
/// ends up displaying can be asserted in both languages without a device.
WidgetSnapshot buildWidgetSnapshot({
  required AppLocalizations l10n,
  required String locale,
  required BridgeStatus status,
  required List<Closure> upcoming,
  required DateTime now,
  required DateTime? fetchedAt,
}) => WidgetSnapshot(
  status: switch (status) {
    BridgeClosed() => l10n.statusClosed,
    BridgeOpen() => l10n.statusOpen,
  },
  updated: fetchedAt == null
      ? ''
      : l10n.updatedAt(Fmt.stamp(locale, fetchedAt)),
  empty: l10n.noUpcomingClosures,
  rows: <WidgetRow>[
    for (final Closure closure in upcoming.take(HomeWidgetService.maxRows))
      WidgetRow(
        when:
            '${Fmt.day(l10n, locale, closure.start, tz.TZDateTime.from(now, closure.start.location))} '
            '${Fmt.time(locale, closure.start)}'
            '>${Fmt.time(locale, closure.end)}',
        what: closure.isMaintenance
            ? l10n.maintenanceLabel
            : closure.vessels.join(' · '),
      ),
  ],
);
