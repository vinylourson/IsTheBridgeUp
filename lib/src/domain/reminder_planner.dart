import 'models/closure.dart';

/// A reminder to be delivered at [at], warning about [closure].
class Reminder {
  const Reminder({required this.at, required this.closure});

  final DateTime at;
  final Closure closure;

  @override
  String toString() => 'Reminder(${at.toIso8601String()} for $closure)';

  @override
  bool operator ==(Object other) =>
      other is Reminder && other.at == at && other.closure == closure;

  @override
  int get hashCode => Object.hash(at, closure);
}

/// Decides which reminders to schedule, and when.
///
/// Pure, so the rules are testable without a device. The platform layer only
/// has to deliver what this produces — which is why the logic is finished
/// even while the web build cannot show notifications.
class ReminderPlanner {
  const ReminderPlanner();

  /// iOS caps pending local notifications at 64; staying well under that
  /// leaves room for anything else the app might schedule later.
  static const int maxReminders = 32;

  /// One reminder per closure, [leadTime] before it starts.
  ///
  /// Closures that have already begun, and those whose reminder instant is
  /// already past, are skipped: a notification that fires immediately for an
  /// event in progress is noise, not a warning.
  List<Reminder> plan({
    required List<Closure> closures,
    required DateTime now,
    required Duration leadTime,
    int max = maxReminders,
  }) {
    final List<Reminder> reminders = <Reminder>[];
    for (final Closure closure in closures) {
      if (!closure.start.isAfter(now)) continue;
      final DateTime fireAt = closure.start.subtract(leadTime);
      if (!fireAt.isAfter(now)) continue;
      reminders.add(Reminder(at: fireAt, closure: closure));
    }
    reminders.sort((Reminder a, Reminder b) => a.at.compareTo(b.at));
    return List<Reminder>.unmodifiable(
      reminders.take(max < 0 ? 0 : max),
    );
  }
}
