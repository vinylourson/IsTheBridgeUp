import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:is_the_bridge_up/src/core/result.dart';
import 'package:is_the_bridge_up/src/data/services/chaban_api_service.dart';

void main() {
  test('asks for records from the given day, inclusive', () async {
    Uri? seen;
    final ChabanApiService api = ChabanApiService(
      client: MockClient((http.Request request) async {
        seen = request.url;
        return http.Response('{"total_count":0,"results":[]}', 200);
      }),
    );

    await api.fetchRecords(from: DateTime.utc(2026, 8, 22));

    // TRAP 1: this must be a date comparison against yesterday, never
    // `>= now()`, which drops closures happening later today.
    expect(seen!.queryParameters['where'], "date_passage >= date'2026-08-22'");
    expect(seen!.queryParameters['order_by'], 'date_passage');
    expect(seen!.host, 'datahub.bordeaux-metropole.fr');
    expect(seen!.path, contains('previsions_pont_chaban'));
  });

  test('zero-pads single-digit months and days', () async {
    Uri? seen;
    final ChabanApiService api = ChabanApiService(
      client: MockClient((http.Request request) async {
        seen = request.url;
        return http.Response('{"results":[]}', 200);
      }),
    );

    await api.fetchRecords(from: DateTime.utc(2026, 1, 5));
    expect(seen!.queryParameters['where'], "date_passage >= date'2026-01-05'");
  });

  test('reads the records envelope', () async {
    final ChabanApiService api = ChabanApiService(
      client: MockClient((_) async => http.Response(
        jsonEncode(<String, Object>{
          'total_count': 1,
          'results': <Map<String, String>>[
            <String, String>{'bateau': 'EVRIMA', 'date_passage': '2026-08-31'},
          ],
        }),
        200,
      )),
    );

    final List<Map<String, dynamic>> rows =
        await api.fetchRecords(from: DateTime.utc(2026, 8, 22));
    expect(rows, hasLength(1));
    expect(rows.single['bateau'], 'EVRIMA');
  });

  test('also reads a bare array, as the data.gouv export returns', () async {
    final ChabanApiService api = ChabanApiService(
      client: MockClient((_) async => http.Response(
        jsonEncode(<Map<String, String>>[
          <String, String>{'bateau': 'AMERA', 'date_passage': '2026-10-22'},
        ]),
        200,
      )),
    );

    final List<Map<String, dynamic>> rows =
        await api.fetchRecords(from: DateTime.utc(2026, 8, 22));
    expect(rows.single['bateau'], 'AMERA');
  });

  test('throws a typed error on a bad status code', () async {
    final ChabanApiService api = ChabanApiService(
      client: MockClient((_) async => http.Response('nope', 503)),
    );

    await expectLater(
      api.fetchRecords(from: DateTime.utc(2026, 8, 22)),
      throwsA(
        isA<ChabanApiException>().having(
          (ChabanApiException e) => e.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
  });

  test('throws a typed error on malformed JSON', () async {
    final ChabanApiService api = ChabanApiService(
      client: MockClient((_) async => http.Response('{not json', 200)),
    );
    await expectLater(
      api.fetchRecords(from: DateTime.utc(2026, 8, 22)),
      throwsA(isA<ChabanApiException>()),
    );
  });

  test('wraps transport failures', () async {
    final ChabanApiService api = ChabanApiService(
      client: MockClient((_) async => throw http.ClientException('down')),
    );
    await expectLater(
      api.fetchRecords(from: DateTime.utc(2026, 8, 22)),
      throwsA(isA<ChabanApiException>()),
    );
  });
}
