import '../../domain/models/closure.dart';
import '../../domain/reminder_planner.dart';

/// Schedules device-local reminders ahead of a closure.
///
/// The interface exists ahead of any implementation on purpose. Reminder
/// *planning* is finished and tested ([ReminderPlanner]); only delivery is
/// platform-specific. `flutter_local_notifications` has no web support and
/// imports dart:io, so the web build gets [UnsupportedNotificationService]
/// and the Alerts screen says so plainly rather than pretending.
abstract interface class NotificationService {
  /// False when this platform cannot deliver local notifications at all.
  bool get isSupported;

  /// Asks the OS for permission. Returns whether it was granted.
  Future<bool> requestPermission();

  /// Replaces all pending reminders with ones for [closures].
  Future<void> schedule({
    required List<Closure> closures,
    required DateTime now,
    required Duration leadTime,
  });

  Future<void> cancelAll();
}

/// Used wherever the platform cannot schedule notifications — currently web.
class UnsupportedNotificationService implements NotificationService {
  const UnsupportedNotificationService();

  @override
  bool get isSupported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule({
    required List<Closure> closures,
    required DateTime now,
    required Duration leadTime,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}
