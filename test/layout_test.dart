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

import 'golden/test_fonts.dart';

const List<Map<String, String>> _records = <Map<String, String>>[
  <String, String>{
    'bateau': 'MV DEUTSCHLAND',
    'date_passage': '2026-08-23',
    'fermeture_a_la_circulation': '14:04',
    're_ouverture_a_la_circulation': '15:27',
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

/// Overflow checks across the range of screens this actually has to work on.
///
/// The tab bar is the tight spot: four Press Start 2P labels side by side, and
/// that face is monospaced at one em per character, so it does not shrink.
/// French labels are the longest, so they get tested too.
void main() {
  late tz.Location paris;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
    await loadPixelFonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    required DateTime now,
    required Locale locale,
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
                notifications: const UnsupportedNotificationService(),
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

  // iPhone SE is the realistic floor; 320 is the paranoid one.
  const List<Size> sizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(375, 667),
    Size(390, 844),
    Size(420, 900),
    Size(600, 900),
    Size(1200, 900),
  ];

  for (final Size size in sizes) {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('fr')]) {
      testWidgets(
        'no overflow at ${size.width.toInt()}x${size.height.toInt()} '
        '(${locale.languageCode})',
        (WidgetTester tester) async {
          await pumpAt(
            tester,
            size,
            now: DateTime.utc(2026, 8, 23, 4),
            locale: locale,
          );
          expect(tester.takeException(), isNull, reason: 'status tab');

          // Every tab, since each has its own worst case.
          for (final String tab in locale.languageCode == 'fr'
              ? const <String>['LISTE', 'ALERTES', 'INFOS', 'ETAT']
              : const <String>['LIST', 'ALERTS', 'INFO', 'STATUS']) {
            await tester.tap(find.text(tab));
            await tester.pump(const Duration(seconds: 1));
            expect(tester.takeException(), isNull, reason: 'tab $tab');
          }
        },
      );
    }
  }

  testWidgets('closed state has no overflow on the smallest screen', (
    WidgetTester tester,
  ) async {
    await pumpAt(
      tester,
      const Size(320, 568),
      now: DateTime.utc(2026, 8, 23, 12, 30),
      locale: const Locale('fr'),
    );
    expect(find.text('PONT FERMÉ'), findsOne);
    expect(tester.takeException(), isNull);
  });
}
