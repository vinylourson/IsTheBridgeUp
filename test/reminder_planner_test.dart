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
      leadTime: const Duration(hours: 1),
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
      leadTime: const Duration(hours: 1),
    );
    // A is under way; warning about it now would be noise.
    expect(plan.map((Reminder r) => r.closure.vesselLabel), <String>['B']);
  });

  test('skips a reminder whose fire time has already passed', () {
    // 30 minutes before A's 14:00 start is 13:30, already gone at 13:45.
    final List<Reminder> plan = planner.plan(
      closures: feed(),
      now: at(23, 13, 45),
      leadTime: const Duration(minutes: 30),
    );
    expect(plan.map((Reminder r) => r.closure.vesselLabel), <String>['B']);
  });

  test('returns reminders in chronological order', () {
    final List<Reminder> plan = planner.plan(
      closures: feed().reversed.toList(),
      now: at(23, 8),
      leadTime: const Duration(hours: 2),
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
        leadTime: const Duration(hours: 1),
        max: 5,
      ),
      hasLength(5),
    );
    expect(ReminderPlanner.maxReminders, lessThan(64));
  });

  test('returns nothing when there is nothing upcoming', () {
    expect(
      planner.plan(
        closures: feed(),
        now: tz.TZDateTime(paris, 2027),
        leadTime: const Duration(hours: 1),
      ),
      isEmpty,
    );
  });
}
