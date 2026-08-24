import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';

/// Formatting helpers shared by the screens.
///
/// Every time shown is Bordeaux local time, because that is what the bridge
/// operates on and what the feed publishes. The Info screen says so.
class Fmt {
  const Fmt._();

  /// A compact countdown, e.g. "2d 09h" or "57m".
  ///
  /// Long waits drop the minutes: at two days out, the minute is noise.
  static String duration(AppLocalizations l10n, Duration d) {
    final Duration abs = d.isNegative ? -d : d;
    if (abs.inMinutes < 1) return l10n.durationLessThanAMinute;

    final int days = abs.inDays;
    final int hours = abs.inHours % 24;
    final int minutes = abs.inMinutes % 60;

    // Drop a zero tail: "1h 0min" and "2d 0h" read like bugs.
    if (days > 0) {
      return hours == 0
          ? l10n.durationDay(days)
          : '${l10n.durationDay(days)} ${l10n.durationHour(hours)}';
    }
    if (hours > 0) {
      return minutes == 0
          ? l10n.durationHour(hours)
          : '${l10n.durationHour(hours)} ${l10n.durationMinute(minutes)}';
    }
    return l10n.durationMinute(minutes);
  }

  /// 24-hour clock, which is what French road signage and the feed both use.
  static String time(String locale, tz.TZDateTime at) =>
      DateFormat.Hm(locale).format(at);

  /// "Today" / "Tomorrow" / "Tue 25 Aug", relative to [now].
  static String day(
    AppLocalizations l10n,
    String locale,
    tz.TZDateTime at,
    tz.TZDateTime now,
  ) {
    final int deltaDays = DateTime(at.year, at.month, at.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return switch (deltaDays) {
      0 => l10n.todayLabel,
      1 => l10n.tomorrowLabel,
      _ => DateFormat.MMMEd(locale).format(at),
    };
  }

  /// Short date plus time, for "last updated" lines.
  static String stamp(String locale, DateTime at) =>
      DateFormat.MMMd(locale).add_Hm().format(at);
}
