import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../core/result.dart';

/// Reads closure forecasts from Bordeaux Métropole's OpenDataSoft Explore
/// v2.1 API. Holds no state.
class ChabanApiService {
  ChabanApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetches raw records with `date_passage` on or after [from].
  ///
  /// [from] should be *yesterday*, not today. `date_passage` is a date at
  /// midnight, so a `>= now()` filter drops closures happening later today —
  /// on 2026-08-23 the live API omitted both of that day's closures. Asking
  /// from yesterday also keeps an overnight closure that began last night and
  /// is still in force this morning.
  Future<List<Map<String, dynamic>>> fetchRecords({required DateTime from}) async {
    final String isoDay = _isoDay(from);
    final Uri uri = Uri.https(ApiConfig.host, ApiConfig.recordsPath, <String, String>{
      'where': "date_passage >= date'$isoDay'",
      'order_by': 'date_passage',
      'limit': '${ApiConfig.pageLimit}',
    });

    final http.Response response;
    try {
      response = await _client.get(uri, headers: const <String, String>{
        'Accept': 'application/json',
      });
    } on Exception catch (error) {
      throw ChabanApiException('Could not reach the open-data API: $error');
    }

    if (response.statusCode != 200) {
      throw ChabanApiException(
        'Unexpected response from the open-data API',
        statusCode: response.statusCode,
      );
    }

    return _decodeRecords(response.body);
  }

  /// Parses either the records-endpoint envelope (`{total_count, results}`)
  /// or a bare array, which is what the data.gouv.fr export permalink returns.
  static List<Map<String, dynamic>> _decodeRecords(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      throw ChabanApiException('Malformed JSON from the open-data API: $error');
    }

    final List<dynamic> rows = switch (decoded) {
      <String, dynamic>{'results': final List<dynamic> results} => results,
      final List<dynamic> list => list,
      _ => throw const ChabanApiException('Unrecognised payload shape'),
    };

    return rows.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static String _isoDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  void dispose() => _client.close();
}
