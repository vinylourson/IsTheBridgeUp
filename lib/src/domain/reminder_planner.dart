import 'models/closure.dart';

/// What a reminder is telling you.
enum ReminderKind {
  /// The bridge is about to close. Fires [Reminder.leadTime] beforehand.
  closing,

  /// The bridge has reopened. Fires at the moment it does.
  reopening,
}

/// A reminder to be delivered at [at], about [closure].
class Reminder {
  const Reminder({
    required this.at,
    required this.closure,
    required this.leadTime,
    this.kind = ReminderKind.closing,
  });

  final DateTime at;
  final Closure closure;
  final ReminderKind kind;

  /// How far ahead of the closure this one fires. Carried on the reminder so
  /// the copy can adapt: a day-ahead warning has to name the day, where an
  /// hour-ahead one does not.
  final Duration leadTime;

  @override
  String toString() =>
      'Reminder(${kind.name} ${at.toIso8601String()} '
      '-${leadTime.inMinutes}min for $closure)';

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.at == at &&
      other.closure == closure &&
      other.leadTime == leadTime &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(at, closure, leadTime, kind);
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

  /// One reminder per closure per selected lead time, plus an optional one
  /// when each closure ends.
  ///
  /// Closures that have already begun get no *closing* warning -- a warning
  /// about something already happening is noise. They do still get a
  /// *reopening* one, which is the case that matters most: you are stood at
  /// the barrier now and want to know when you can cross.
  ///
  /// The result is sorted by fire time and truncated, so when the selection
  /// would exceed the cap it is the *soonest* reminders that survive.
  List<Reminder> plan({
    required List<Closure> closures,
    required DateTime now,
    required Set<Duration> leadTimes,
    bool notifyReopening = false,
    int max = maxReminders,
  }) {
    final List<Reminder> reminders = <Reminder>[];
    for (final Closure closure in closures) {
      if (notifyReopening && closure.end.isAfter(now)) {
        reminders.add(
          Reminder(
            at: closure.end,
            closure: closure,
            leadTime: Duration.zero,
            kind: ReminderKind.reopening,
          ),
        );
      }
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
      if (byTime != 0) return byTime;
      // Stable ordering when two reminders land on the same instant: one
      // closure's reopening can coincide with the next one's warning.
      final int byKind = a.kind.index.compareTo(b.kind.index);
      return byKind != 0 ? byKind : a.leadTime.compareTo(b.leadTime);
    });
    return List<Reminder>.unmodifiable(reminders.take(max < 0 ? 0 : max));
  }
}
