import 'dart:collection';

import 'package:timezone/timezone.dart' as tz;

import 'models/bridge_status.dart';
import 'models/closure.dart';

/// Turns raw feed records into [Closure]s and answers "can I cross right now?".
///
/// Deliberately pure: no HTTP, no widgets, no ambient clock. Everything the
/// app can get wrong about time lives here, where it is cheap to test.
///
/// The feed gives a bare date plus two `HH:mm` wall-clock times with no zone.
/// They are always Europe/Paris, so they are resolved through [location]
/// rather than the device zone — otherwise a user abroad, or a CI runner on
/// UTC, would be told the wrong thing.
class BridgeClock {
  BridgeClock(this.location, {DateTime Function()? now}) : _nowOverride = now;

  final tz.Location location;

  /// Lets tests pin the current instant. Production leaves it null and reads
  /// the real clock.
  final DateTime Function()? _nowOverride;

  tz.TZDateTime now() {
    final DateTime Function()? override = _nowOverride;
    return override == null
        ? tz.TZDateTime.now(location)
        : tz.TZDateTime.from(override(), location);
  }

  /// Parses one record, returning null if it is malformed rather than throwing:
  /// one bad row must not blank the whole schedule.
  Closure? parseRecord(Map<String, dynamic> record) {
    final String? rawDate = _asString(record['date_passage']);
    final String? rawClose = _asString(record['fermeture_a_la_circulation']);
    final String? rawOpen = _asString(record['re_ouverture_a_la_circulation']);
    if (rawDate == null || rawClose == null || rawOpen == null) return null;

    // `date_passage` is 'YYYY-MM-DD', but tolerate a full timestamp.
    final List<String> dateParts = rawDate.split('T').first.split('-');
    if (dateParts.length < 3) return null;
    final int? year = int.tryParse(dateParts[0]);
    final int? month = int.tryParse(dateParts[1]);
    final int? day = int.tryParse(dateParts[2]);
    if (year == null || month == null || day == null) return null;

    final _HourMinute? close = _parseHourMinute(rawClose);
    final _HourMinute? open = _parseHourMinute(rawOpen);
    if (close == null || open == null) return null;

    // TRAP: six records in the feed reopen *before* they close
    // (e.g. 23:00 -> 05:00 maintenance). Those roll over to the next day;
    // reading them as same-day yields a negative duration.
    final bool rollsOver = open.asMinutes <= close.asMinutes;

    final tz.TZDateTime start = tz.TZDateTime(
      location,
      year,
      month,
      day,
      close.hour,
      close.minute,
    );

    // Built from calendar fields rather than `start.add(Duration(days: 1))`
    // so that a closure spanning a DST change keeps the right wall clock:
    // adding an absolute 24h would land an hour off.
    final tz.TZDateTime end = tz.TZDateTime(
      location,
      year,
      month,
      day + (rollsOver ? 1 : 0),
      open.hour,
      open.minute,
    );

    return Closure(
      vesselLabel: _asString(record['bateau'])?.trim() ?? '',
      start: start,
      end: end,
      closureType: _asString(record['type_de_fermeture'])?.trim() ?? '',
      isTotal:
          (_asString(record['fermeture_totale'])?.trim().toLowerCase() ??
              'oui') !=
          'non',
    );
  }

  /// Parses every record, drops malformed ones, removes duplicates and sorts
  /// chronologically.
  ///
  /// TRAP: the API does not order rows by time within a day — the live feed
  /// returned 14:04 before 04:19 for the same date. Never trust its order.
  List<Closure> parseRecords(Iterable<Map<String, dynamic>> records) {
    final LinkedHashSet<Closure> unique = LinkedHashSet<Closure>();
    for (final Map<String, dynamic> record in records) {
      final Closure? closure = parseRecord(record);
      if (closure != null) unique.add(closure);
    }
    final List<Closure> sorted = unique.toList();
    sorted.sort((Closure a, Closure b) {
      final int byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.end.compareTo(b.end);
    });
    return List<Closure>.unmodifiable(sorted);
  }

  /// Whether the bridge is open or closed at [instant].
  ///
  /// [closures] is expected to be sorted, as returned by [parseRecords].
  BridgeStatus statusAt(DateTime instant, List<Closure> closures) {
    Closure? active;
    for (final Closure closure in closures) {
      if (!closure.contains(instant)) continue;
      // Overlapping closures (several boats in one window) should report the
      // latest reopening, never an early one.
      if (active == null || closure.end.isAfter(active.end)) active = closure;
    }

    if (active != null) {
      return BridgeClosed(
        current: active,
        nextClosure: _firstStartingAfter(active.end, closures),
      );
    }
    return BridgeOpen(nextClosure: _firstStartingAfter(instant, closures));
  }

  /// Closures still relevant at [instant]: the one in progress, if any, plus
  /// everything still to come.
  List<Closure> upcomingFrom(DateTime instant, List<Closure> closures) =>
      List<Closure>.unmodifiable(
        closures.where((Closure c) => c.end.isAfter(instant)),
      );

  Closure? _firstStartingAfter(DateTime instant, List<Closure> closures) {
    for (final Closure closure in closures) {
      if (closure.start.isAfter(instant)) return closure;
    }
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static _HourMinute? _parseHourMinute(String raw) {
    final List<String> parts = raw.split(':');
    if (parts.length < 2) return null;
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return _HourMinute(hour, minute);
  }
}

class _HourMinute {
  const _HourMinute(this.hour, this.minute);
  final int hour;
  final int minute;
  int get asMinutes => hour * 60 + minute;
}
