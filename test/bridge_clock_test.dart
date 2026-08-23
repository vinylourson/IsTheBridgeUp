import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:is_the_bridge_up/src/domain/bridge_clock.dart';
import 'package:is_the_bridge_up/src/domain/models/bridge_status.dart';
import 'package:is_the_bridge_up/src/domain/models/closure.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Builds a feed record the same shape the ODS v2.1 API returns.
Map<String, dynamic> record({
  required String date,
  required String close,
  required String open,
  String boat = 'TEST BOAT',
  String type = 'Totale',
  String total = 'oui',
}) => <String, dynamic>{
  'bateau': boat,
  'date_passage': date,
  'fermeture_a_la_circulation': close,
  're_ouverture_a_la_circulation': open,
  'type_de_fermeture': type,
  'fermeture_totale': total,
};

void main() {
  late BridgeClock clock;
  late tz.Location paris;

  setUpAll(() {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
    clock = BridgeClock(paris);
  });

  tz.TZDateTime parisAt(int y, int mo, int d, int h, [int mi = 0]) =>
      tz.TZDateTime(paris, y, mo, d, h, mi);

  group('parseRecord', () {
    test('resolves a same-day closure in Europe/Paris', () {
      final Closure c = clock.parseRecord(
        record(date: '2026-08-23', close: '14:04', open: '15:27'),
      )!;

      expect(c.start, parisAt(2026, 8, 23, 14, 4));
      expect(c.end, parisAt(2026, 8, 23, 15, 27));
      expect(c.duration, const Duration(hours: 1, minutes: 23));
      expect(c.isOvernight, isFalse);
      // Paris is UTC+2 in August; the instant must be absolute, not local.
      expect(c.start.toUtc(), DateTime.utc(2026, 8, 23, 12, 4));
    });

    test('rolls an overnight closure over to the next day', () {
      // TRAP 3: six live records reopen before they close.
      final Closure c = clock.parseRecord(
        record(
          date: '2026-08-19',
          close: '23:00',
          open: '05:00',
          boat: 'MAINTENANCE',
        ),
      )!;

      expect(c.start, parisAt(2026, 8, 19, 23));
      expect(c.end, parisAt(2026, 8, 20, 5));
      expect(c.duration, const Duration(hours: 6));
      expect(c.isOvernight, isTrue);
      expect(c.duration.isNegative, isFalse);
    });

    test('rolls over across a month boundary', () {
      final Closure c = clock.parseRecord(
        record(date: '2026-08-31', close: '23:30', open: '04:00'),
      )!;
      expect(c.end, parisAt(2026, 9, 1, 4));
      expect(c.duration, const Duration(hours: 4, minutes: 30));
    });

    test('spring-forward night is 5 real hours, not 6', () {
      // Paris skips 02:00->03:00 on 2026-03-29. Wall clock says 6h;
      // the true elapsed time is 5h. A countdown must use the real one.
      final Closure c = clock.parseRecord(
        record(date: '2026-03-28', close: '23:00', open: '05:00'),
      )!;
      expect(c.duration, const Duration(hours: 5));
      expect(c.start.toUtc(), DateTime.utc(2026, 3, 28, 22));
      expect(c.end.toUtc(), DateTime.utc(2026, 3, 29, 3));
    });

    test('fall-back night is 7 real hours, not 6', () {
      // Paris repeats 02:00->03:00 on 2026-10-25.
      final Closure c = clock.parseRecord(
        record(date: '2026-10-24', close: '23:00', open: '05:00'),
      )!;
      expect(c.duration, const Duration(hours: 7));
      expect(c.start.toUtc(), DateTime.utc(2026, 10, 24, 21));
      expect(c.end.toUtc(), DateTime.utc(2026, 10, 25, 4));
    });

    test('flags maintenance and splits multi-vessel labels', () {
      final Closure maintenance = clock.parseRecord(
        record(
          date: '2026-08-19',
          close: '23:00',
          open: '05:00',
          boat: 'MAINTENANCE',
        ),
      )!;
      expect(maintenance.isMaintenance, isTrue);
      expect(maintenance.vessels, isEmpty);

      final Closure convoy = clock.parseRecord(
        record(
          date: '2026-08-31',
          close: '09:44',
          open: '12:02',
          boat: 'EVRIMA - SILVER SPIRIT',
        ),
      )!;
      expect(convoy.isMaintenance, isFalse);
      expect(convoy.vessels, <String>['EVRIMA', 'SILVER SPIRIT']);
    });

    test('returns null on malformed rows instead of throwing', () {
      expect(clock.parseRecord(<String, dynamic>{}), isNull);
      expect(
        clock.parseRecord(record(date: 'not-a-date', close: '1:00', open: '2:00')),
        isNull,
      );
      expect(
        clock.parseRecord(record(date: '2026-08-23', close: '99:99', open: '2:00')),
        isNull,
      );
      expect(
        clock.parseRecord(record(date: '2026-08-23', close: '', open: '2:00')),
        isNull,
      );
    });
  });

  group('parseRecords', () {
    test('sorts chronologically even when the feed does not', () {
      // TRAP 2: the live API returned 14:04 before 04:19 for the same date.
      final List<Closure> closures = clock.parseRecords(<Map<String, dynamic>>[
        record(date: '2026-08-23', close: '14:04', open: '15:27'),
        record(date: '2026-08-23', close: '04:19', open: '05:27'),
        record(date: '2026-08-22', close: '15:29', open: '16:37'),
      ]);

      expect(
        closures.map((Closure c) => c.start),
        <tz.TZDateTime>[
          parisAt(2026, 8, 22, 15, 29),
          parisAt(2026, 8, 23, 4, 19),
          parisAt(2026, 8, 23, 14, 4),
        ],
      );
    });

    test('drops malformed rows without losing the good ones', () {
      final List<Closure> closures = clock.parseRecords(<Map<String, dynamic>>[
        record(date: '2026-08-23', close: '14:04', open: '15:27'),
        <String, dynamic>{'bateau': 'BROKEN'},
        record(date: '2026-08-25', close: '17:49', open: '19:57'),
      ]);
      expect(closures, hasLength(2));
    });

    test('removes duplicate rows', () {
      final List<Closure> closures = clock.parseRecords(<Map<String, dynamic>>[
        record(date: '2026-08-23', close: '14:04', open: '15:27'),
        record(date: '2026-08-23', close: '14:04', open: '15:27'),
      ]);
      expect(closures, hasLength(1));
    });
  });

  group('statusAt', () {
    final List<Map<String, dynamic>> feed = <Map<String, dynamic>>[
      record(date: '2026-08-23', close: '14:04', open: '15:27', boat: 'MV DEUTSCHLAND'),
      record(date: '2026-08-23', close: '04:19', open: '05:27', boat: 'AZAMARA QUEST'),
      record(date: '2026-08-25', close: '17:49', open: '19:57', boat: 'STAR LEGEND'),
    ];

    test('reports closed mid-closure, with the correct reopening', () {
      final List<Closure> closures = clock.parseRecords(feed);
      final BridgeStatus status = clock.statusAt(
        parisAt(2026, 8, 23, 14, 30),
        closures,
      );

      expect(status, isA<BridgeClosed>());
      final BridgeClosed closed = status as BridgeClosed;
      expect(closed.current.vesselLabel, 'MV DEUTSCHLAND');
      expect(
        closed.timeUntilReopen(parisAt(2026, 8, 23, 14, 30)),
        const Duration(minutes: 57),
      );
      expect(closed.nextClosure?.vesselLabel, 'STAR LEGEND');
    });

    test('is closed at the exact start and open at the exact reopening', () {
      final List<Closure> closures = clock.parseRecords(feed);

      expect(
        clock.statusAt(parisAt(2026, 8, 23, 14, 4), closures),
        isA<BridgeClosed>(),
      );
      // The minute it reopens you can cross, so the end is exclusive.
      expect(
        clock.statusAt(parisAt(2026, 8, 23, 15, 27), closures),
        isA<BridgeOpen>(),
      );
    });

    test('reports open with the next closure and time until it', () {
      final List<Closure> closures = clock.parseRecords(feed);
      final BridgeStatus status = clock.statusAt(
        parisAt(2026, 8, 23, 10),
        closures,
      );

      expect(status, isA<BridgeOpen>());
      final BridgeOpen open = status as BridgeOpen;
      expect(open.nextClosure?.vesselLabel, 'MV DEUTSCHLAND');
      expect(
        open.timeUntilClosure(parisAt(2026, 8, 23, 10)),
        const Duration(hours: 4, minutes: 4),
      );
    });

    test('reports open with no next closure once the feed runs out', () {
      final List<Closure> closures = clock.parseRecords(feed);
      final BridgeStatus status = clock.statusAt(
        parisAt(2026, 12, 1, 10),
        closures,
      );
      expect(status, isA<BridgeOpen>());
      expect((status as BridgeOpen).nextClosure, isNull);
      expect(open_(status).timeUntilClosure(parisAt(2026, 12, 1, 10)), isNull);
    });

    test('prefers the latest reopening when closures overlap', () {
      final List<Closure> closures = clock.parseRecords(<Map<String, dynamic>>[
        record(date: '2026-08-23', close: '14:00', open: '15:00', boat: 'FIRST'),
        record(date: '2026-08-23', close: '14:30', open: '16:00', boat: 'SECOND'),
      ]);
      final BridgeClosed closed =
          clock.statusAt(parisAt(2026, 8, 23, 14, 45), closures)
              as BridgeClosed;
      // Reporting FIRST would send someone to the bridge an hour early.
      expect(closed.current.vesselLabel, 'SECOND');
    });

    test('progress runs 0 -> 1 across the closure', () {
      final List<Closure> closures = clock.parseRecords(feed);
      final BridgeClosed closed =
          clock.statusAt(parisAt(2026, 8, 23, 14, 30), closures) as BridgeClosed;

      expect(closed.progress(parisAt(2026, 8, 23, 14, 4)), 0);
      expect(closed.progress(parisAt(2026, 8, 23, 15, 27)), 1);
      expect(closed.progress(parisAt(2026, 8, 23, 13)), 0); // clamped
      expect(closed.progress(parisAt(2026, 8, 23, 14, 45)), closeTo(0.494, 0.01));
    });
  });

  group('upcomingFrom', () {
    test('keeps an in-progress closure and everything after it', () {
      final List<Closure> closures = clock.parseRecords(<Map<String, dynamic>>[
        record(date: '2026-08-22', close: '15:29', open: '16:37'),
        record(date: '2026-08-23', close: '04:19', open: '05:27'),
        record(date: '2026-08-23', close: '14:04', open: '15:27'),
      ]);

      final List<Closure> upcoming = clock.upcomingFrom(
        parisAt(2026, 8, 23, 14, 30),
        closures,
      );
      expect(upcoming, hasLength(1));
      expect(upcoming.single.start, parisAt(2026, 8, 23, 14, 4));
    });
  });

  group('live fixture', () {
    // Captured from the real API on 2026-08-23 (see test/fixtures).
    late List<Closure> closures;

    setUpAll(() {
      final File file = File('test/fixtures/records_around_today.json');
      final Map<String, dynamic> payload =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      closures = clock.parseRecords(
        (payload['results'] as List<dynamic>).cast<Map<String, dynamic>>(),
      );
    });

    test('parses every row in the real payload', () {
      expect(closures, hasLength(7));
    });

    test("does not drop today's closures", () {
      // TRAP 1: `where=date_passage >= now()` silently omitted both of these,
      // because date_passage is midnight and midnight today is already past.
      final List<Closure> today = closures
          .where(
            (Closure c) => c.start.year == 2026 && c.start.month == 8 && c.start.day == 23,
          )
          .toList();

      expect(today, hasLength(2));
      expect(
        today.map((Closure c) => c.vesselLabel),
        <String>['AZAMARA QUEST', 'MV DEUTSCHLAND'],
      );
      // Asked at breakfast, both of today's closures are still ahead.
      expect(
        clock.upcomingFrom(parisAt(2026, 8, 23, 3), closures),
        hasLength(5),
      );
    });

    test('finds the real overnight maintenance window', () {
      final Closure overnight = closures.firstWhere((Closure c) => c.isOvernight);
      expect(overnight.isMaintenance, isTrue);
      expect(overnight.start, parisAt(2026, 8, 19, 23));
      expect(overnight.end, parisAt(2026, 8, 20, 5));
      expect(overnight.duration, const Duration(hours: 6));
    });

    test('every parsed closure has a positive duration', () {
      for (final Closure c in closures) {
        expect(c.duration.isNegative, isFalse, reason: '$c');
        expect(c.duration, greaterThan(Duration.zero), reason: '$c');
      }
    });
  });
}

BridgeOpen open_(BridgeStatus s) => s as BridgeOpen;
