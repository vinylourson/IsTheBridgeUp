import 'package:flutter/foundation.dart';

import '../../domain/bridge_clock.dart';
import '../../domain/models/closure.dart';
import '../services/chaban_api_service.dart';
import '../services/closure_cache_service.dart';

/// Single source of truth for the closure schedule.
///
/// Cache-first: the last snapshot is shown immediately (so the app is useful
/// offline and opens without a spinner), then a refresh runs in the
/// background. A failed refresh never clears good cached data — being shown
/// slightly old times beats being shown nothing while standing at the bridge.
class ClosureRepository extends ChangeNotifier {
  ClosureRepository({
    required this._api,
    required this._cache,
    required this._clock,
  });

  final ChabanApiService _api;
  final ClosureCacheService _cache;
  final BridgeClock _clock;

  /// The feed is republished at most a few times a week, so this is generous.
  static const Duration staleAfter = Duration(hours: 6);

  List<Closure> _closures = const <Closure>[];
  DateTime? _fetchedAt;
  bool _isRefreshing = false;
  Object? _error;

  List<Closure> get closures => _closures;
  DateTime? get fetchedAt => _fetchedAt;
  bool get isRefreshing => _isRefreshing;

  /// Set only when the most recent refresh failed. Data may still be present.
  Object? get error => _error;

  bool get hasData => _fetchedAt != null;

  bool get isStale {
    final DateTime? at = _fetchedAt;
    if (at == null) return true;
    return _clock.now().difference(at) > staleAfter;
  }

  /// Loads the cached snapshot, then refreshes from the network.
  Future<void> load() async {
    final CachedRecords? cached = await _cache.read();
    if (cached != null) {
      _closures = _clock.parseRecords(cached.records);
      _fetchedAt = cached.fetchedAt;
      notifyListeners();
    }
    await refresh();
  }

  /// Fetches from the API and replaces the cached snapshot on success.
  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _error = null;
    notifyListeners();

    try {
      // Deliberately yesterday, not today — see ChabanApiService.fetchRecords.
      final DateTime from = _clock.now().subtract(const Duration(days: 1));
      final List<Map<String, dynamic>> records = await _api.fetchRecords(
        from: from,
      );
      final DateTime now = _clock.now();

      _closures = _clock.parseRecords(records);
      _fetchedAt = now;
      await _cache.write(records, fetchedAt: now);
    } on Object catch (error) {
      _error = error;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
