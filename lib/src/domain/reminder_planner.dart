import 'models/closure.dart';

/// A reminder to be delivered at [at], warning about [closure].
class Reminder {
  const Reminder({
    required this.at,
    required this.closure,
    required this.leadTime,
  });

  final DateTime at;
  final Closure closure;

  /// How far ahead of the closure this one fires. Carried on the reminder so
  /// the copy can adapt: a day-ahead warning has to name the day, where an
  /// hour-ahead one does not.
  final Duration leadTime;

  @override
  String toString() =>
      'Reminder(${at.toIso8601String()} '
      '-${leadTime.inMinutes}min for $closure)';

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.at == at &&
      other.closure == closure &&
      other.leadTime == leadTime;

  @override
  int get hashCode => Object.hash(at, closure, leadTime);
}

/// Decides which reminders to schedule, and when.
///
/// Pure, so the rules are testable without a device.
class ReminderPlanner {
  const ReminderPlanner();

  /// iOS caps pending local notifications at 64 per app. Several lead times
  /// multiply the count — a day-ahead plus an hour-ahead doubles it — so the
  /// ceiling leaves real headroom rather than sitting near the limit.
  static const int maxReminders = 48;

  /// The lead times a user can choose from.
  static const List<Duration> leadTimeOptions = <Duration>[
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(days: 1),
  ];

  /// One reminder per closure per selected lead time.
  ///
  /// Closures that have already begun are skipped, as are reminders whose fire
  /// time is already past: a notification that arrives for something in
  /// progress is noise, not a warning.
  ///
  /// The result is sorted by fire time and truncated, so when the selection
  /// would exceed the cap it is the *soonest* reminders that survive.
  List<Reminder> plan({
    required List<Closure> closures,
    required DateTime now,
    required Set<Duration> leadTimes,
    int max = maxReminders,
  }) {
    final List<Reminder> reminders = <Reminder>[];
    for (final Closure closure in closures) {
      if (!closure.start.isAfter(now)) continue;
      for (final Duration leadTime in leadTimes) {
        final DateTime fireAt = closure.start.subtract(leadTime);
        if (!fireAt.isAfter(now)) continue;
        reminders.add(
          Reminder(at: fireAt, closure: closure, leadTime: leadTime),
        );
      }
    }
    reminders.sort((Reminder a, Reminder b) {
      final int byTime = a.at.compareTo(b.at);
      // Stable ordering when two lead times land on the same instant.
      return byTime != 0
          ? byTime
          : a.leadTime.compareTo(b.leadTime);
    });
    return List<Reminder>.unmodifiable(reminders.take(max < 0 ? 0 : max));
  }
}
