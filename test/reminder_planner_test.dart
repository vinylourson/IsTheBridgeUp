import 'package:flutter_test/flutter_test.dart';
import 'package:is_the_bridge_up/src/domain/bridge_clock.dart';
import 'package:is_the_bridge_up/src/domain/models/closure.dart';
import 'package:is_the_bridge_up/src/domain/reminder_planner.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late BridgeClock clock;
  late tz.Location paris;
  const ReminderPlanner planner = ReminderPlanner();

  setUpAll(() {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
    clock = BridgeClock(paris);
  });

  tz.TZDateTime at(int d, int h, [int mi = 0]) =>
      tz.TZDateTime(paris, 2026, 8, d, h, mi);

  List<Closure> feed() => clock.parseRecords(<Map<String, dynamic>>[
    <String, dynamic>{
      'bateau': 'A',
      'date_passage': '2026-08-23',
      'fermeture_a_la_circulation': '14:00',
      're_ouverture_a_la_circulation': '15:00',
      'type_de_fermeture': 'Totale',
      'fermeture_totale': 'oui',
    },
    <String, dynamic>{
      'bateau': 'B',
      'date_passage': '2026-08-25',
      'fermeture_a_la_circulation': '09:00',
      're_ouverture_a_la_circulation': '10:00',
      'type_de_fermeture': 'Totale',
      'fermeture_totale': 'oui',
    },
  ]);

  test('schedules one reminder per closure, ahead by the lead time', () {
    final List<Reminder> plan = planner.plan(
      closures: feed(),
      now: at(23, 8),
      leadTimes: <Duration>{const Duration(hours: 1)},
    );

    expect(plan, hasLength(2));
    expect(plan.first.at, at(23, 13));
    expect(plan.first.closure.vesselLabel, 'A');
    expect(plan.last.at, at(25, 8));
  });

  test('skips a closure already in progress', () {
    final List<Reminder> plan = planner.plan(
      closures: feed(),
      now: at(23, 14, 30),
      leadTimes: <Duration>{const Duration(hours: 1)},
    );
    // A is under way; warning about it now would be noise.
    expect(plan.map((Reminder r) => r.closure.vesselLabel), <String>['B']);
  });

  test('skips a reminder whose fire time has already passed', () {
    // 30 minutes before A's 14:00 start is 13:30, already gone at 13:45.
    final List<Reminder> plan = planner.plan(
      closures: feed(),
      now: at(23, 13, 45),
      leadTimes: <Duration>{const Duration(minutes: 30)},
    );
    expect(plan.map((Reminder r) => r.closure.vesselLabel), <String>['B']);
  });

  test('returns reminders in chronological order', () {
    final List<Reminder> plan = planner.plan(
      closures: feed().reversed.toList(),
      now: at(23, 8),
      leadTimes: <Duration>{const Duration(hours: 2)},
    );
    expect(plan.first.at.isBefore(plan.last.at), isTrue);
  });

  test('caps the number of reminders to stay under the iOS limit', () {
    final List<Closure> many = clock.parseRecords(<Map<String, dynamic>>[
      for (int day = 1; day <= 28; day++)
        <String, dynamic>{
          'bateau': 'BOAT $day',
          'date_passage': '2026-09-${day.toString().padLeft(2, '0')}',
          'fermeture_a_la_circulation': '12:00',
          're_ouverture_a_la_circulation': '13:00',
          'type_de_fermeture': 'Totale',
          'fermeture_totale': 'oui',
        },
    ]);

    expect(
      planner.plan(
        closures: many,
        now: at(23, 8),
        leadTimes: <Duration>{const Duration(hours: 1)},
        max: 5,
      ),
      hasLength(5),
    );
    expect(ReminderPlanner.maxReminders, lessThan(64),
        reason: 'iOS caps pending notifications at 64');
  });

  test('returns nothing when there is nothing upcoming', () {
    expect(
      planner.plan(
        closures: feed(),
        now: tz.TZDateTime(paris, 2027),
        leadTimes: <Duration>{const Duration(hours: 1)},
      ),
      isEmpty,
    );
  });

  group('several lead times', () {
    test('one closure produces one reminder per lead time', () {
      final List<Reminder> plan = planner.plan(
        closures: feed(),
        now: at(22, 8),
        leadTimes: <Duration>{
          const Duration(hours: 1),
          const Duration(days: 1),
        },
      );

      // Two closures x two leads.
      expect(plan, hasLength(4));
      final List<Reminder> forA =
          plan.where((Reminder r) => r.closure.vesselLabel == 'A').toList();
      expect(forA, hasLength(2));
      expect(
        forA.map((Reminder r) => r.leadTime).toSet(),
        <Duration>{const Duration(hours: 1), const Duration(days: 1)},
      );
    });

    test('a day-ahead reminder fires 24h before the closure', () {
      final List<Reminder> plan = planner.plan(
        closures: feed(),
        now: at(22, 8),
        leadTimes: <Duration>{const Duration(days: 1)},
      );
      // A closes 2026-08-23 14:00, so the day-ahead lands on the 22nd.
      expect(plan.first.at, at(22, 14));
      expect(plan.first.leadTime, const Duration(days: 1));
    });

    test('each reminder carries the lead it came from', () {
      final List<Reminder> plan = planner.plan(
        closures: feed(),
        now: at(22, 8),
        leadTimes: <Duration>{
          const Duration(minutes: 30),
          const Duration(hours: 4),
        },
      );
      for (final Reminder r in plan) {
        expect(r.closure.start.difference(r.at), r.leadTime);
      }
    });

    test('results stay sorted across lead times', () {
      final List<Reminder> plan = planner.plan(
        closures: feed(),
        now: at(22, 8),
        leadTimes: <Duration>{
          const Duration(hours: 1),
          const Duration(days: 1),
          const Duration(minutes: 30),
        },
      );
      for (int i = 1; i < plan.length; i++) {
        expect(
          plan[i].at.isBefore(plan[i - 1].at),
          isFalse,
          reason: 'reminder $i is out of order',
        );
      }
    });

    test('when the cap bites, the soonest reminders survive', () {
      final List<Closure> many = clock.parseRecords(<Map<String, dynamic>>[
        for (int day = 1; day <= 28; day++)
          <String, dynamic>{
            'bateau': 'BOAT $day',
            'date_passage': '2026-09-${day.toString().padLeft(2, '0')}',
            'fermeture_a_la_circulation': '12:00',
            're_ouverture_a_la_circulation': '13:00',
            'type_de_fermeture': 'Totale',
            'fermeture_totale': 'oui',
          },
      ]);

      final List<Reminder> plan = planner.plan(
        closures: many,
        now: at(22, 8),
        leadTimes: <Duration>{
          const Duration(hours: 1),
          const Duration(days: 1),
        },
        max: 6,
      );
      expect(plan, hasLength(6));
      // Truncation must drop the far future, not the imminent: six slots over
      // two leads covers the first three closures and nothing beyond.
      expect(plan.first.closure.vesselLabel, 'BOAT 1');
      final Set<int> boats = plan
          .map((Reminder r) => int.parse(r.closure.vesselLabel.split(' ').last))
          .toSet();
      expect(boats, <int>{1, 2, 3});
    });

    test('no lead times means no reminders', () {
      expect(
        planner.plan(
          closures: feed(),
          now: at(22, 8),
          leadTimes: const <Duration>{},
        ),
        isEmpty,
      );
    });
  });
}
