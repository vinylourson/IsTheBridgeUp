@Tags(<String>['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:is_the_bridge_up/src/data/services/chaban_api_service.dart';
import 'package:is_the_bridge_up/src/domain/bridge_clock.dart';
import 'package:is_the_bridge_up/src/domain/models/closure.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A canary against the live feed.
///
/// The previous version of this app died silently when Bordeaux Métropole
/// retired the OpenDataSoft v1 API. These tests fail loudly if the endpoint
/// moves again or the schema changes shape.
void main() {
  late BridgeClock clock;

  setUpAll(() {
    tzdata.initializeTimeZones();
    clock = BridgeClock(tz.getLocation('Europe/Paris'));
  });

  test('the live endpoint still answers with the expected schema', () async {
    final ChabanApiService api = ChabanApiService();
    final DateTime from = DateTime.now().subtract(const Duration(days: 400));

    final List<Map<String, dynamic>> rows = await api.fetchRecords(from: from);
    expect(rows, isNotEmpty, reason: 'the feed returned no rows at all');

    // Every field the app reads must still be present.
    for (final String field in const <String>[
      'bateau',
      'date_passage',
      'fermeture_a_la_circulation',
      're_ouverture_a_la_circulation',
      'type_de_fermeture',
      'fermeture_totale',
    ]) {
      expect(
        rows.first.containsKey(field),
        isTrue,
        reason: 'the feed no longer publishes "$field"',
      );
    }

    final List<Closure> closures = clock.parseRecords(rows);
    expect(
      closures.length,
      rows.length,
      reason: 'some live rows failed to parse',
    );
    for (final Closure c in closures) {
      expect(c.duration, greaterThan(Duration.zero), reason: '$c');
      expect(
        c.duration,
        lessThan(const Duration(hours: 24)),
        reason: 'implausibly long closure: $c',
      );
    }

    api.dispose();
  });
}
