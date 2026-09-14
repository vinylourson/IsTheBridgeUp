// Tagged `golden` as well as `store`: these are rendered goldens, and
// rendered goldens do not match across platforms, so CI must skip them the
// same way it skips the app goldens. `store` stays so the set can still be
// regenerated on its own.
@Tags(<String>['golden', 'store'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:is_the_bridge_up/src/app.dart';
import 'package:is_the_bridge_up/src/data/repositories/closure_repository.dart';
import 'package:is_the_bridge_up/src/data/services/alert_preferences_service.dart';
import 'package:is_the_bridge_up/src/data/services/chaban_api_service.dart';
import 'package:is_the_bridge_up/src/data/services/closure_cache_service.dart';
import 'package:is_the_bridge_up/src/data/services/notification_service.dart';
import 'package:is_the_bridge_up/src/domain/bridge_clock.dart';
import 'package:is_the_bridge_up/src/ui/alerts/alerts_view_model.dart';
import 'package:is_the_bridge_up/src/ui/status/status_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'golden/test_fonts.dart';
import 'support/fake_notifications.dart';

/// Generates the store listing screenshots, for F-Droid, IzzyOnDroid and
/// anywhere else that reads fastlane metadata.
///
/// Rendered rather than captured from a device: the closed state only exists
/// for a couple of hours at a time, and a real device cannot be asked to show
/// it on demand. Rendering also makes the set reproducible and bilingual.
///
/// Tagged `store` so it stays out of the normal run. Regenerate with:
///   flutter test --tags store --update-goldens
void main() {
  late tz.Location paris;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
    await loadPixelFonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  const List<Map<String, String>> records = <Map<String, String>>[
    <String, String>{
      'bateau': 'AIDASOL',
      'date_passage': '2026-08-23',
      'fermeture_a_la_circulation': '14:04',
      're_ouverture_a_la_circulation': '15:27',
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
      'bateau': 'MAINTENANCE',
      'date_passage': '2026-08-27',
      'fermeture_a_la_circulation': '23:00',
      're_ouverture_a_la_circulation': '05:00',
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

  Future<void> pump(
    WidgetTester tester, {
    required DateTime now,
    required Locale locale,
    NotificationService notifications = const UnsupportedNotificationService(),
  }) async {
    // A real phone's logical size, at 2.5x so the PNGs are store resolution
    // (1050x2250) rather than the 420x900 the goldens use.
    tester.view.physicalSize = const Size(1050, 2250);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    // Tear the old tree down first. Calling pumpWidget again with a
    // structurally identical tree makes Flutter reuse the elements, and
    // Provider then keeps the view model it built the first time -- so a
    // later call's notification service is silently ignored.
    await tester.pumpWidget(const SizedBox.shrink());

    final BridgeClock clock = BridgeClock(paris, now: () => now);
    final ClosureRepository repository = ClosureRepository(
      api: ChabanApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object>{'results': records}),
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
        data: const MediaQueryData(disableAnimations: true),
        child: MultiProvider(
          providers: [
            Provider<BridgeClock>.value(value: clock),
            Provider<NotificationService>.value(value: notifications),
            ChangeNotifierProvider<ClosureRepository>.value(value: repository),
            ChangeNotifierProvider<StatusViewModel>(
              create: (_) =>
                  StatusViewModel(repository: repository, clock: clock),
            ),
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
    await tester.pump(const Duration(seconds: 2));
  }

  Future<void> shot(WidgetTester tester, String locale, int n) =>
      expectLater(
        find.byType(IsTheBridgeUpApp),
        matchesGoldenFile('../metadata/$locale/images/phoneScreenshots/$n.png'),
      );

  for (final ({String dir, Locale locale, List<String> tabs}) target
      in <({String dir, Locale locale, List<String> tabs})>[
    (dir: 'en-US', locale: Locale('en'), tabs: <String>['LIST', 'ALERTS', 'INFO']),
    (dir: 'fr-FR', locale: Locale('fr'), tabs: <String>['LISTE', 'ALERTES', 'INFOS']),
  ]) {
    testWidgets('store screenshots – ${target.dir}', (
      WidgetTester tester,
    ) async {
      // 1. Open, with traffic crossing.
      await pump(
        tester,
        now: DateTime.utc(2026, 8, 23, 4),
        locale: target.locale,
      );
      await shot(tester, target.dir, 1);

      // 2. Closed, with the ship passing through. The state the app exists
      //    for, and the one a device screenshot can almost never catch.
      await pump(
        tester,
        now: DateTime.utc(2026, 8, 23, 12, 30),
        locale: target.locale,
      );
      await shot(tester, target.dir, 2);

      // 3. The schedule.
      await pump(
        tester,
        now: DateTime.utc(2026, 8, 23, 4),
        locale: target.locale,
      );
      await tester.tap(find.text(target.tabs[0]));
      await tester.pump(const Duration(seconds: 2));
      await shot(tester, target.dir, 3);

      // 4. Alerts, switched on so the screenshot shows the real thing.
      await pump(
        tester,
        now: DateTime.utc(2026, 8, 23, 4),
        locale: target.locale,
        notifications: FakeNotifications(
          initialPermission: NotificationPermission.granted,
        ),
      );
      await tester.tap(find.text(target.tabs[1]));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(
        find.text(target.dir == 'en-US' ? 'Turn alerts on' : 'Activer les alertes'),
      );
      await tester.pump(const Duration(seconds: 2));
      await shot(tester, target.dir, 4);

      // 5. Info, including the provenance of the data.
      await pump(
        tester,
        now: DateTime.utc(2026, 8, 23, 4),
        locale: target.locale,
      );
      await tester.tap(find.text(target.tabs[2]));
      await tester.pump(const Duration(seconds: 2));
      await shot(tester, target.dir, 5);
    });
  }
}
