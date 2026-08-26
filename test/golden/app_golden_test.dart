@Tags(<String>['golden'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:is_the_bridge_up/src/app.dart';
import 'package:is_the_bridge_up/src/data/repositories/closure_repository.dart';
import 'package:is_the_bridge_up/src/data/services/chaban_api_service.dart';
import 'package:is_the_bridge_up/src/data/services/closure_cache_service.dart';
import 'package:is_the_bridge_up/src/data/services/alert_preferences_service.dart';
import 'package:is_the_bridge_up/src/data/services/notification_service.dart';
import 'package:is_the_bridge_up/src/domain/bridge_clock.dart';
import 'package:is_the_bridge_up/src/ui/alerts/alerts_view_model.dart';
import 'package:is_the_bridge_up/src/ui/status/status_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../support/fake_notifications.dart';
import 'test_fonts.dart';

/// Records around 2026-08-23, matching the live fixture: two closures that
/// day (stored out of order) and an overnight maintenance window.
const List<Map<String, String>> _records = <Map<String, String>>[
  <String, String>{
    'bateau': 'MAINTENANCE',
    'date_passage': '2026-08-19',
    'fermeture_a_la_circulation': '23:00',
    're_ouverture_a_la_circulation': '05:00',
    'type_de_fermeture': 'Totale',
    'fermeture_totale': 'oui',
  },
  <String, String>{
    'bateau': 'MV DEUTSCHLAND',
    'date_passage': '2026-08-23',
    'fermeture_a_la_circulation': '14:04',
    're_ouverture_a_la_circulation': '15:27',
    'type_de_fermeture': 'Totale',
    'fermeture_totale': 'oui',
  },
  <String, String>{
    'bateau': 'AZAMARA QUEST',
    'date_passage': '2026-08-23',
    'fermeture_a_la_circulation': '04:19',
    're_ouverture_a_la_circulation': '05:27',
    'type_de_fermeture': 'Totale',
    'fermeture_totale': 'oui',
  },
  <String, String>{
    'bateau': 'AZAMARA QUEST - STAR LEGEND',
    'date_passage': '2026-08-25',
    'fermeture_a_la_circulation': '17:49',
    're_ouverture_a_la_circulation': '19:57',
    'type_de_fermeture': 'Totale',
    'fermeture_totale': 'oui',
  },
  <String, String>{
    'bateau': 'EVRIMA - SILVER SPIRIT',
    'date_passage': '2026-08-31',
    'fermeture_a_la_circulation': '09:44',
    're_ouverture_a_la_circulation': '12:02',
    'type_de_fermeture': 'Totale',
    'fermeture_totale': 'oui',
  },
];

void main() {
  late tz.Location paris;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
    await loadPixelFonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpApp(
    WidgetTester tester, {
    required DateTime now,
    Locale locale = const Locale('en'),
    Size size = const Size(420, 900),
    NotificationService notifications = const UnsupportedNotificationService(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final BridgeClock clock = BridgeClock(paris, now: () => now);
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
    await repository.load();

    await tester.pumpWidget(
      MediaQuery(
        // Pins the drifting ship and traffic so goldens are deterministic.
        data: const MediaQueryData(disableAnimations: true),
        child: MultiProvider(
          providers: [
            Provider<BridgeClock>.value(value: clock),
            Provider<NotificationService>.value(
              value: const UnsupportedNotificationService(),
            ),
            ChangeNotifierProvider<ClosureRepository>.value(value: repository),
            ChangeNotifierProvider<StatusViewModel>(
              create: (_) =>
                  StatusViewModel(repository: repository, clock: clock),
            ),
            // Unsupported on purpose: a widget test has no platform channels,
            // and this also exercises the "cannot schedule here" path.
            ChangeNotifierProvider<AlertsViewModel>(
              create: (_) => AlertsViewModel(
                notifications: notifications,
                preferences: AlertPreferencesService(),
                repository: repository,
                clock: clock,
              ),
            ),
          ],
          child: IsTheBridgeUpApp(locale: locale),
        ),
      ),
    );
    // Let the lift animation settle.
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('status – open, English', (WidgetTester tester) async {
    await pumpApp(tester, now: DateTime.utc(2026, 8, 23, 4)); // 06:00 Paris
    expect(find.text('BRIDGE OPEN'), findsOne);
    await expectLater(
      find.byType(IsTheBridgeUpApp),
      matchesGoldenFile('goldens/status_open_en.png'),
    );
  });

  testWidgets('status – closed, English', (WidgetTester tester) async {
    await pumpApp(tester, now: DateTime.utc(2026, 8, 23, 12, 30)); // 14:30
    expect(find.text('BRIDGE CLOSED'), findsOne);
    await expectLater(
      find.byType(IsTheBridgeUpApp),
      matchesGoldenFile('goldens/status_closed_en.png'),
    );
  });

  testWidgets('status – closed, French accents render', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      now: DateTime.utc(2026, 8, 23, 12, 30),
      locale: const Locale('fr'),
    );
    expect(find.text('PONT FERMÉ'), findsOne);
    await expectLater(
      find.byType(IsTheBridgeUpApp),
      matchesGoldenFile('goldens/status_closed_fr.png'),
    );
  });

  testWidgets('schedule list', (WidgetTester tester) async {
    await pumpApp(tester, now: DateTime.utc(2026, 8, 23, 4));
    await tapTab(tester, 'LIST');
    await expectLater(
      find.byType(IsTheBridgeUpApp),
      matchesGoldenFile('goldens/schedule_en.png'),
    );
  });

  testWidgets('smallest screen, French – tightest tab bar', (
    WidgetTester tester,
  ) async {
    // 320pt is the narrowest screen worth supporting, and the French tab
    // labels are the longest. If anything clips, it clips here.
    await pumpApp(
      tester,
      now: DateTime.utc(2026, 8, 23, 12, 30),
      locale: const Locale('fr'),
      size: const Size(320, 640),
    );
    await expectLater(
      find.byType(IsTheBridgeUpApp),
      matchesGoldenFile('goldens/status_closed_fr_320.png'),
    );
  });

  testWidgets('alerts – on, with reminders scheduled', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      now: DateTime.utc(2026, 8, 23, 4),
      notifications: FakeNotifications(
        initialPermission: NotificationPermission.granted,
      ),
    );
    await tapTab(tester, 'ALERTS');
    await tester.tap(find.text('Turn alerts on'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ALERTS ON'), findsOne);
    // Add a day-ahead lead alongside the default hour, so the golden shows
    // more than one selected.
    await tester.tap(find.text('1d'));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byType(IsTheBridgeUpApp),
      matchesGoldenFile('goldens/alerts_on_en.png'),
    );
  });

  testWidgets('alerts – blocked by the system, French', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      now: DateTime.utc(2026, 8, 23, 4),
      locale: const Locale('fr'),
      notifications: FakeNotifications(grantOnRequest: false),
    );
    await tapTab(tester, 'ALERTES');
    await tester.tap(find.text('Activer les alertes'));
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byType(IsTheBridgeUpApp),
      matchesGoldenFile('goldens/alerts_blocked_fr.png'),
    );
  });

  testWidgets('info screen, French', (WidgetTester tester) async {
    await pumpApp(
      tester,
      now: DateTime.utc(2026, 8, 23, 4),
      locale: const Locale('fr'),
    );
    await tapTab(tester, 'INFOS');
    await expectLater(
      find.byType(IsTheBridgeUpApp),
      matchesGoldenFile('goldens/info_fr.png'),
    );
  });
}
