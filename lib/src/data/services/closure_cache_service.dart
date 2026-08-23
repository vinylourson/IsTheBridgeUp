import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';

/// A cached schedule snapshot and when it was taken.
class CachedRecords {
  const CachedRecords({required this.records, required this.fetchedAt});

  final List<Map<String, dynamic>> records;
  final DateTime fetchedAt;
}

/// Persists the last successful fetch so the app opens instantly and keeps
/// working offline. Raw records are stored rather than parsed closures, so a
/// later fix to the parsing rules applies to already-cached data.
class ClosureCacheService {
  Future<CachedRecords?> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(CacheKeys.records);
    final String? stamp = prefs.getString(CacheKeys.fetchedAt);
    if (raw == null || stamp == null) return null;

    final DateTime? fetchedAt = DateTime.tryParse(stamp);
    if (fetchedAt == null) return null;

    try {
      final List<dynamic> rows = jsonDecode(raw) as List<dynamic>;
      return CachedRecords(
        records: rows.whereType<Map<String, dynamic>>().toList(growable: false),
        fetchedAt: fetchedAt,
      );
    } on Object {
      // A corrupt cache must never be fatal; treat it as absent.
      await clear();
      return null;
    }
  }

  Future<void> write(
    List<Map<String, dynamic>> records, {
    required DateTime fetchedAt,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(CacheKeys.records, jsonEncode(records));
    await prefs.setString(CacheKeys.fetchedAt, fetchedAt.toIso8601String());
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(CacheKeys.records);
    await prefs.remove(CacheKeys.fetchedAt);
  }
}
