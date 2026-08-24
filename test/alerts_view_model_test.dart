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
    expect(t.vm.leadTime, const Duration(hours: 1));
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

  test('a refused prompt schedules nothing and reports being blocked', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build(notifications: FakeNotifications(grantOnRequest: false));
    await t.repo.load();
    await t.vm.load();

    await t.vm.setEnabled(true);

    expect(t.vm.permission, NotificationPermission.denied);
    expect(t.fake.scheduled, isEmpty);
    // The screen needs to explain, not offer the button again.
    expect(t.vm.blockedBySystem, isTrue);
  });

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

  test('changing the lead time moves the reminders', () async {
    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    t = build();
    await t.repo.load();
    await t.vm.load();
    await t.vm.setEnabled(true);

    final DateTime oneHour = t.fake.scheduled.first.at;
    await t.vm.setLeadTime(const Duration(hours: 4));
    final DateTime fourHours = t.fake.scheduled.first.at;

    expect(t.vm.leadTime, const Duration(hours: 4));
    expect(oneHour.difference(fourHours), const Duration(hours: 3));
  });

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
    await first.vm.setLeadTime(const Duration(minutes: 30));

    final ({AlertsViewModel vm, FakeNotifications fake, ClosureRepository repo})
    second = build(
      notifications: FakeNotifications(
        initialPermission: NotificationPermission.granted,
      ),
    );
    await second.repo.load();
    await second.vm.load();

    expect(second.vm.enabled, isTrue);
    expect(second.vm.leadTime, const Duration(minutes: 30));
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
}
