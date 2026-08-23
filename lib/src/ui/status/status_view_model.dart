import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/closure_repository.dart';
import '../../domain/bridge_clock.dart';
import '../../domain/models/bridge_status.dart';
import '../../domain/models/closure.dart';

/// Drives the status screen: the verdict, the countdown, and the load state.
///
/// Ticks once a second so the countdown stays honest, and recomputes the
/// verdict on every tick — a closure can begin while the screen is open.
class StatusViewModel extends ChangeNotifier {
  StatusViewModel({required this._repository, required this._clock}) {
    _repository.addListener(_onRepositoryChanged);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _now = _clock.now();
  }

  final ClosureRepository _repository;
  final BridgeClock _clock;

  late Timer _ticker;
  late DateTime _now;

  DateTime get now => _now;

  BridgeStatus get status => _clock.statusAt(_now, _repository.closures);

  List<Closure> get upcoming => _clock.upcomingFrom(_now, _repository.closures);

  bool get isRefreshing => _repository.isRefreshing;
  bool get hasData => _repository.hasData;
  bool get isStale => _repository.isStale;
  Object? get error => _repository.error;
  DateTime? get fetchedAt => _repository.fetchedAt;

  /// True when there is nothing to show at all: no cache and a failed fetch.
  bool get isBlank => !hasData && !isRefreshing;

  Future<void> refresh() => _repository.refresh();

  void _tick() {
    _now = _clock.now();
    notifyListeners();
  }

  void _onRepositoryChanged() {
    _now = _clock.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.cancel();
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
