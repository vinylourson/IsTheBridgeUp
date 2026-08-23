import 'closure.dart';

/// Whether the bridge can be crossed at a given instant.
sealed class BridgeStatus {
  const BridgeStatus();

  /// The closure this status is about: the active one when closed, the next
  /// one when open. Null only when the feed holds nothing upcoming.
  Closure? get relevantClosure;
}

/// The bridge is open to traffic.
final class BridgeOpen extends BridgeStatus {
  const BridgeOpen({this.nextClosure});

  /// The next scheduled closure, or null if the feed has none left.
  final Closure? nextClosure;

  @override
  Closure? get relevantClosure => nextClosure;

  /// How long until the bridge closes, or null if nothing is scheduled.
  Duration? timeUntilClosure(DateTime from) =>
      nextClosure?.start.difference(from);

  @override
  String toString() => 'BridgeOpen(next: $nextClosure)';
}

/// The bridge is closed: a boat is passing, or maintenance is under way.
final class BridgeClosed extends BridgeStatus {
  const BridgeClosed({required this.current, this.nextClosure});

  /// The closure currently in progress.
  final Closure current;

  /// The closure after this one, if any.
  final Closure? nextClosure;

  @override
  Closure? get relevantClosure => current;

  /// How long until traffic resumes.
  Duration timeUntilReopen(DateTime from) => current.end.difference(from);

  /// How far through the closure we are, clamped to 0..1.
  double progress(DateTime at) {
    final int total = current.duration.inSeconds;
    if (total <= 0) return 1;
    final int done = at.difference(current.start).inSeconds;
    return (done / total).clamp(0.0, 1.0);
  }

  @override
  String toString() => 'BridgeClosed($current)';
}
