import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:is_the_bridge_up/src/data/repositories/closure_repository.dart';
import 'package:is_the_bridge_up/src/data/services/chaban_api_service.dart';
import 'package:is_the_bridge_up/src/data/services/closure_cache_service.dart';
import 'package:is_the_bridge_up/src/domain/bridge_clock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
    'bateau': 'AZAMARA QUEST',
    'date_passage': '2026-08-23',
    'fermeture_a_la_circulation': '04:19',
    're_ouverture_a_la_circulation': '05:27',
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

  BridgeClock clockAt(DateTime now) => BridgeClock(paris, now: () => now);

  ClosureRepository build({
    required BridgeClock clock,
    required http.Client client,
  }) => ClosureRepository(
    api: ChabanApiService(client: client),
    cache: ClosureCacheService(),
    clock: clock,
  );

  http.Client okClient({int calls = 0}) => MockClient(
    (_) async => http.Response(
      jsonEncode(<String, Object>{'total_count': 2, 'results': _records}),
      200,
    ),
  );

  test('fetches, sorts and caches on a cold start', () async {
    final ClosureRepository repo = build(
      clock: clockAt(DateTime.utc(2026, 8, 23, 6)),
      client: okClient(),
    );

    await repo.load();

    expect(repo.hasData, isTrue);
    expect(repo.error, isNull);
    expect(repo.closures, hasLength(2));
    // Sorted despite the feed listing 14:04 first.
    expect(repo.closures.first.vesselLabel, 'AZAMARA QUEST');

    final CachedRecords? cached = await ClosureCacheService().read();
    expect(cached, isNotNull);
    expect(cached!.records, hasLength(2));
  });

  test('serves the cache before the network, then refreshes', () async {
    await ClosureCacheService().write(
      _records.map((Map<String, String> r) => <String, dynamic>{...r}).toList(),
      fetchedAt: DateTime.utc(2026, 8, 23, 5),
    );

    final List<int> snapshotSizes = <int>[];
    final ClosureRepository repo = build(
      clock: clockAt(DateTime.utc(2026, 8, 23, 6)),
      client: okClient(),
    );
    repo.addListener(() => snapshotSizes.add(repo.closures.length));

    await repo.load();

    // Data was available from the very first notification, i.e. before any
    // network call resolved.
    expect(snapshotSizes.first, 2);
    expect(repo.closures, hasLength(2));
  });

  test('a failed refresh keeps cached data and records the error', () async {
    await ClosureCacheService().write(
      _records.map((Map<String, String> r) => <String, dynamic>{...r}).toList(),
      fetchedAt: DateTime.utc(2026, 8, 23, 5),
    );

    final ClosureRepository repo = build(
      clock: clockAt(DateTime.utc(2026, 8, 23, 6)),
      client: MockClient((_) async => http.Response('boom', 500)),
    );

    await repo.load();

    // Being shown slightly stale times beats being shown nothing.
    expect(repo.closures, hasLength(2));
    expect(repo.hasData, isTrue);
    expect(repo.error, isNotNull);
  });

  test('cold start with a failing network leaves no data but no crash', () async {
    final ClosureRepository repo = build(
      clock: clockAt(DateTime.utc(2026, 8, 23, 6)),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    await repo.load();

    expect(repo.closures, isEmpty);
    expect(repo.hasData, isFalse);
    expect(repo.error, isNotNull);
  });

  test('a corrupt cache is discarded rather than fatal', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'chaban.records.v1': '{not json',
      'chaban.fetchedAt.v1': DateTime.utc(2026, 8, 23, 5).toIso8601String(),
    });

    final ClosureRepository repo = build(
      clock: clockAt(DateTime.utc(2026, 8, 23, 6)),
      client: okClient(),
    );

    await repo.load();
    expect(repo.closures, hasLength(2));
  });

  test('marks data stale once past the threshold', () async {
    final ClosureRepository repo = build(
      clock: clockAt(DateTime.utc(2026, 8, 23, 6)),
      client: okClient(),
    );
    expect(repo.isStale, isTrue, reason: 'no data yet');

    await repo.load();
    expect(repo.isStale, isFalse);

    // Same cached snapshot, read much later.
    final ClosureRepository later = build(
      clock: clockAt(
        DateTime.utc(2026, 8, 23, 6).add(
          ClosureRepository.staleAfter + const Duration(minutes: 1),
        ),
      ),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await later.load();
    expect(later.isStale, isTrue);
  });

  test('concurrent refreshes collapse into one', () async {
    int calls = 0;
    final ClosureRepository repo = build(
      clock: clockAt(DateTime.utc(2026, 8, 23, 6)),
      client: MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(
          jsonEncode(<String, Object>{'results': _records}),
          200,
        );
      }),
    );

    await Future.wait<void>(<Future<void>>[repo.refresh(), repo.refresh()]);
    expect(calls, 1);
  });
}
