import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:is_the_bridge_up/src/data/repositories/closure_repository.dart';
import 'package:is_the_bridge_up/src/data/services/alert_preferences_service.dart';
import 'package:is_the_bridge_up/src/data/services/chaban_api_service.dart';
import 'package:is_the_bridge_up/src/data/services/closure_cache_service.dart';
import 'package:is_the_bridge_up/src/data/services/notification_service.dart';
import 'package:is_the_bridge_up/src/domain/bridge_clock.dart';
import 'package:is_the_bridge_up/src/domain/models/closure.dart';
import 'package:is_the_bridge_up/src/domain/reminder_planner.dart';
import 'package:is_the_bridge_up/src/ui/alerts/alerts_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_notifications.dart';

const List<Map<String, String>> _records = <Map<String, String>>[
  <String, String>{
    'bateau': 'MV DEUTSCHLAND',
    'date_passage': '2026-08-25',
    'fermeture_a_la_circulation': '14:00',
    're_ouverture_a_la_circulation': '15:00',
    'type_de_fermeture': 'Totale',
    'fermeture_totale': 'oui',
  },
  <String, String>{
    'bateau': 'MAINTENANCE',
    'date_passage': '2026-08-27',
    'fermeture_a_la_circulation': '23:00',
    're_ouverture_a_la_circulation': '05:00',
    'type_de_fermeture': 'Totale',
    'fermeture_totale': 'oui',
  },
];

void main() {
  late tz.Location paris;

  setUpAll(() {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo}) build({
    FakeNotifications? notifications,
  }) {
    final BridgeClock clock = BridgeClock(
      paris,
      now: () => DateTime.utc(2026, 8, 24, 6),
    );
    final ClosureRepository repository = ClosureRepository(
      api: ChabanApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object>{'results': _records}),
            200,
          ),
        ),
      ),
      cache: ClosureCacheService(),
      clock: clock,
    );
    final FakeNotifications fake = notifications ?? FakeNotifications();
    final AlertsViewModel vm = AlertsViewModel(
      notifications: fake,
      preferences: AlertPreferencesService(),
      repository: repository,
      clock: clock,
    );
    vm.attachText(
      (Reminder r) => (title: 'Bridge closes', body: r.closure.vesselLabel),
    );
    return (vm: vm, fake: fake, repo: repository);
  }

  test('starts off, and asks for nothing until told to', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build();
    await t.repo.load();
    await t.vm.load();

    expect(t.vm.enabled, isFalse);
    expect(t.vm.leadTimes, <Duration>{const Duration(hours: 1)});
    // Critically: no permission prompt on load. Asking before the user has
    // said they want alerts gets it denied.
    expect(t.fake.requestCount, 0);
    expect(t.fake.scheduled, isEmpty);
  });

  test('turning alerts on prompts once and schedules', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build();
    await t.repo.load();
    await t.vm.load();

    await t.vm.setEnabled(true);

    expect(t.fake.requestCount, 1);
    expect(t.vm.permission, NotificationPermission.granted);
    expect(t.vm.enabled, isTrue);
    expect(t.fake.scheduled, hasLength(2));
    expect(t.vm.scheduledCount, 2);
  });

  test('does not prompt again when permission is already granted', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build(
      notifications: FakeNotifications(
        initialPermission: NotificationPermission.granted,
      ),
    );
    await t.repo.load();
    await t.vm.load();

    await t.vm.setEnabled(true);
    expect(t.fake.requestCount, 0, reason: 'already granted');
    expect(t.fake.scheduled, hasLength(2));
  });

  test(
    'a refused prompt schedules nothing and reports being blocked',
    () async {
      final ({
        AlertsViewModel vm,
        FakeNotifications fake,
        ClosureRepository repo,
      })
      t = build(notifications: FakeNotifications(grantOnRequest: false));
      await t.repo.load();
      await t.vm.load();

      await t.vm.setEnabled(true);

      expect(t.vm.permission, NotificationPermission.denied);
      expect(t.fake.scheduled, isEmpty);
      // The screen needs to explain, not offer the button again.
      expect(t.vm.blockedBySystem, isTrue);
    },
  );

  test('turning alerts off cancels everything', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build();
    await t.repo.load();
    await t.vm.load();
    await t.vm.setEnabled(true);

    await t.vm.setEnabled(false);
    expect(t.vm.enabled, isFalse);
    expect(t.fake.scheduled, isEmpty);
    expect(t.vm.scheduledCount, 0);
  });

  test(
    'adding a lead time adds reminders rather than replacing them',
    () async {
      final ({
        AlertsViewModel vm,
        FakeNotifications fake,
        ClosureRepository repo,
      })
      t = build();
      await t.repo.load();
      await t.vm.load();
      await t.vm.setEnabled(true);

      final int withOneLead = t.fake.scheduled.length;

      await t.vm.toggleLeadTime(const Duration(days: 1));

      expect(t.vm.leadTimes, hasLength(2));
      expect(
        t.fake.scheduled.length,
        withOneLead * 2,
        reason: 'each closure now warns twice',
      );
    },
  );

  test('a feed refresh re-lays the reminders', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build();
    await t.repo.load();
    await t.vm.load();
    await t.vm.setEnabled(true);
    final int before = t.fake.scheduleCount;

    await t.repo.refresh();
    await Future<void>.delayed(Duration.zero);

    expect(
      t.fake.scheduleCount,
      greaterThan(before),
      reason: 'the schedule shifts when the feed does',
    );
  });

  test('settings survive a restart', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    first = build();
    await first.repo.load();
    await first.vm.load();
    await first.vm.setEnabled(true);
    await first.vm.toggleLeadTime(const Duration(minutes: 30));

    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    second = build(
      notifications: FakeNotifications(
        initialPermission: NotificationPermission.granted,
      ),
    );
    await second.repo.load();
    await second.vm.load();

    expect(second.vm.enabled, isTrue);
    expect(second.vm.leadTimes, <Duration>{
      const Duration(hours: 1),
      const Duration(minutes: 30),
    });
    expect(second.fake.scheduled, isNotEmpty, reason: 're-laid on launch');
  });

  test('where scheduling is impossible, nothing is attempted', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build(notifications: FakeNotifications(canSchedule: false));
    await t.repo.load();
    await t.vm.load();

    expect(t.vm.canSchedule, isFalse);
    await t.vm.setEnabled(true);
    expect(t.fake.scheduled, isEmpty);
  });

  test('the last lead time cannot be removed', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build();
    await t.repo.load();
    await t.vm.load();

    expect(t.vm.leadTimes, hasLength(1));
    // Alerts on with no timing would schedule nothing while claiming to work.
    await t.vm.toggleLeadTime(t.vm.leadTimes.single);
    expect(t.vm.leadTimes, hasLength(1));
  });

  test('a deselected lead time stops producing reminders', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build();
    await t.repo.load();
    await t.vm.load();
    await t.vm.setEnabled(true);
    await t.vm.toggleLeadTime(const Duration(days: 1));
    final int withTwo = t.fake.scheduled.length;

    await t.vm.toggleLeadTime(const Duration(days: 1));
    expect(t.vm.leadTimes, hasLength(1));
    expect(t.fake.scheduled.length, lessThan(withTwo));
  });

  test('reopening alerts are opt-in, and add a reminder per closure', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build();
    await t.repo.load();
    await t.vm.load();
    await t.vm.setEnabled(true);

    expect(t.vm.notifyReopening, isFalse, reason: 'opt-in, not a default');
    final int closingOnly = t.fake.scheduled.length;

    await t.vm.setNotifyReopening(true);

    expect(t.vm.notifyReopening, isTrue);
    expect(t.fake.scheduled.length, closingOnly * 2);
    expect(
      t.fake.scheduled.where((Reminder r) => r.kind == ReminderKind.reopening),
      hasLength(closingOnly),
    );
  });

  test('turning reopening back off removes those reminders', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build();
    await t.repo.load();
    await t.vm.load();
    await t.vm.setEnabled(true);
    await t.vm.setNotifyReopening(true);

    await t.vm.setNotifyReopening(false);
    expect(
      t.fake.scheduled.any((Reminder r) => r.kind == ReminderKind.reopening),
      isFalse,
    );
  });

  test('the reopening preference survives a restart', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    first = build();
    await first.repo.load();
    await first.vm.load();
    await first.vm.setNotifyReopening(true);

    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    second = build();
    await second.repo.load();
    await second.vm.load();
    expect(second.vm.notifyReopening, isTrue);
  });

  group('notification ids', () {
    tz.TZDateTime at(int day, int hour, [int minute = 0]) =>
        tz.TZDateTime(paris, 2026, 8, day, hour, minute);

    Closure closure(int day, int h1, int h2, String vessel) => Closure(
      vesselLabel: vessel,
      start: at(day, h1),
      end: at(day, h2),
      closureType: 'Totale',
      isTotal: true,
    );

    Reminder reminder(Closure c, Duration lead, ReminderKind kind) => Reminder(
      at: c.start.subtract(lead),
      closure: c,
      leadTime: lead,
      kind: kind,
    );

    test('two lead times for one closure share an id', () {
      // Otherwise they post as two separate cards, and because the copy names
      // absolute times they read word for word identically -- which is what a
      // user actually saw: the same notification apparently twice.
      final Closure c = closure(23, 14, 15, 'BALMORAL');
      expect(
        LocalNotificationService.notificationIdFor(
          reminder(c, const Duration(hours: 1), ReminderKind.closing),
        ),
        LocalNotificationService.notificationIdFor(
          reminder(c, const Duration(minutes: 30), ReminderKind.closing),
        ),
      );
    });

    test('different closures get different ids', () {
      expect(
        LocalNotificationService.notificationIdFor(
          reminder(
            closure(23, 14, 15, 'A'),
            const Duration(hours: 1),
            ReminderKind.closing,
          ),
        ),
        isNot(
          LocalNotificationService.notificationIdFor(
            reminder(
              closure(24, 14, 15, 'B'),
              const Duration(hours: 1),
              ReminderKind.closing,
            ),
          ),
        ),
      );
    });

    test('closing and reopening do not collide', () {
      // They post on different channels, and a posted notification cannot
      // change channel, so they must not share an id.
      final Closure c = closure(23, 14, 15, 'BALMORAL');
      expect(
        LocalNotificationService.notificationIdFor(
          reminder(c, const Duration(hours: 1), ReminderKind.closing),
        ),
        isNot(
          LocalNotificationService.notificationIdFor(
            reminder(c, Duration.zero, ReminderKind.reopening),
          ),
        ),
      );
    });

    test('ids stay a positive 32-bit int', () {
      // Android notification ids are ints; a negative or overflowing value
      // would be rejected or silently collide.
      for (final ReminderKind kind in ReminderKind.values) {
        final int id = LocalNotificationService.notificationIdFor(
          reminder(closure(23, 14, 15, 'A'), const Duration(hours: 1), kind),
        );
        expect(id, greaterThan(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });

    test('the id is stable across reschedules', () {
      // A feed refresh re-lays every reminder. An unstable id would add a new
      // card each time instead of updating the one already showing.
      final Closure c = closure(23, 14, 15, 'BALMORAL');
      final int first = LocalNotificationService.notificationIdFor(
        reminder(c, const Duration(hours: 1), ReminderKind.closing),
      );
      final int second = LocalNotificationService.notificationIdFor(
        reminder(c, const Duration(hours: 1), ReminderKind.closing),
      );
      expect(first, second);
    });
  });
}
