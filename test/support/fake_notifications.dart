import 'package:flutter_test/flutter_test.dart';
import 'package:is_the_bridge_up/src/data/services/notification_service.dart';
import 'package:is_the_bridge_up/src/domain/reminder_planner.dart';

/// Records what the platform layer was asked to do, so the permission flow can
/// be tested without a device.
class FakeNotifications implements NotificationService {
  FakeNotifications({
    this.canSchedule = true,
    this.grantOnRequest = true,
    this.initialPermission = NotificationPermission.unknown,
  }) : _permission = initialPermission;

  @override
  final bool canSchedule;
  final bool grantOnRequest;
  final NotificationPermission initialPermission;

  NotificationPermission _permission;
  List<Reminder> scheduled = <Reminder>[];
  int requestCount = 0;
  int cancelCount = 0;
  int scheduleCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermission> permission() async => _permission;

  @override
  Future<NotificationPermission> requestPermission() async {
    requestCount++;
    _permission = grantOnRequest
        ? NotificationPermission.granted
        : NotificationPermission.denied;
    return _permission;
  }

  @override
  Future<void> schedule({
    required List<Reminder> reminders,
    required ReminderText text,
  }) async {
    scheduleCount++;
    scheduled = List<Reminder>.of(reminders);
    // Exercise the copy builder the same way the real service does.
    for (final Reminder r in reminders) {
      final ({String title, String body}) copy = text(r);
      expect(copy.title, isNotEmpty);
      expect(copy.body, isNotEmpty);
    }
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
    scheduled = <Reminder>[];
  }

  @override
  Future<int> pendingCount() async => scheduled.length;
}

