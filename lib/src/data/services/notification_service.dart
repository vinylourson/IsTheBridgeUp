import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/reminder_planner.dart';

/// Whether the OS will let us post notifications.
enum NotificationPermission {
  /// Not asked yet, or the platform will not say.
  unknown,
  granted,

  /// Refused, or switched off later in system settings. Only the user can
  /// undo this — asking again does nothing.
  denied,
}

/// Builds the text for one reminder.
///
/// A callback rather than baked-in strings, so the localised copy stays in the
/// UI layer and this service carries no l10n dependency.
typedef ReminderText = ({String title, String body}) Function(Reminder reminder);

abstract interface class NotificationService {
  /// False where the platform cannot post a notification at a *future* time.
  bool get canSchedule;

  Future<void> initialize();

  /// Current permission state, without prompting.
  Future<NotificationPermission> permission();

  /// Prompts the user. This is what shows the OS dialog.
  Future<NotificationPermission> requestPermission();

  /// Replaces all pending reminders with these.
  Future<void> schedule({
    required List<Reminder> reminders,
    required ReminderText text,
  });

  Future<void> cancelAll();

  /// How many reminders the OS is actually holding.
  Future<int> pendingCount();
}

/// Real implementation, backed by flutter_local_notifications.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialised = false;

  // Two channels rather than one, so Android's own notification settings let
  // you keep the closing warnings and silence the reopening ones, or the
  // reverse, without turning the app's alerts off entirely.
  static const String _closingChannelId = 'chaban.closures';
  static const String _closingChannelName = 'Bridge closures';
  static const String _closingChannelDescription =
      'Warnings before the Chaban-Delmas bridge closes to traffic.';

  static const String _reopeningChannelId = 'chaban.reopenings';
  static const String _reopeningChannelName = 'Bridge reopenings';
  static const String _reopeningChannelDescription =
      'Told when the Chaban-Delmas bridge reopens to traffic.';

  /// Tints the status-bar icon and the notification accent. Matches
  /// PixelPalette.open; duplicated rather than imported so this service keeps
  /// no dependency on the UI layer.
  static const Color _accent = Color(0xFF9AD284);

  /// The plugin builds for web, but `zonedSchedule` throws there: a browser
  /// cannot run code to post a notification once the tab is closed.
  @override
  bool get canSchedule => !kIsWeb;

  @override
  Future<void> initialize() async {
    if (_initialised) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        // NOT the launcher icon: Android builds the status-bar icon from the
        // alpha channel alone and paints every opaque pixel white, so an
        // opaque launcher icon arrives as a featureless white blob.
        // ic_stat_bridge is a transparent silhouette drawn for the purpose.
        android: AndroidInitializationSettings('ic_stat_bridge'),
        // Permission is requested from the Alerts screen instead of here, so
        // the prompt appears when the user asks for alerts. Asking on first
        // launch, before the app has explained itself, gets it denied.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialised = true;
  }

  @override
  Future<NotificationPermission> permission() async {
    if (!canSchedule) return NotificationPermission.unknown;
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return _fromBool(await android.areNotificationsEnabled());
    }

    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final NotificationsEnabledOptions? options = await ios.checkPermissions();
      return _fromBool(options?.isEnabled);
    }
    return NotificationPermission.unknown;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    if (!canSchedule) return NotificationPermission.unknown;
    await initialize();

    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      // Deliberately not requesting SCHEDULE_EXACT_ALARM: on Android 14+ that
      // throws the user out to a system settings page, and a warning an hour
      // ahead does not need to-the-second delivery. See the schedule mode
      // chosen below.
      return _fromBool(await android.requestNotificationsPermission());
    }

    final IOSFlutterLocalNotificationsPlugin? ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return _fromBool(
        await ios.requestPermissions(alert: true, badge: true, sound: true),
      );
    }
    return NotificationPermission.unknown;
  }

  @override
  Future<void> schedule({
    required List<Reminder> reminders,
    required ReminderText text,
  }) async {
    if (!canSchedule) return;
    await initialize();
    // Replace wholesale: the schedule shifts when the feed updates, and
    // reconciling individual ids would be more code and more ways to be wrong.
    await cancelAll();

    for (int i = 0; i < reminders.length; i++) {
      final Reminder reminder = reminders[i];
      final ({String title, String body}) copy = text(reminder);
      final NotificationDetails details = _detailsFor(reminder.kind);
      await _plugin.zonedSchedule(
        id: i,
        scheduledDate: tz.TZDateTime.from(
          reminder.at,
          reminder.closure.start.location,
        ),
        notificationDetails: details,
        // Inexact on purpose. An exact alarm needs SCHEDULE_EXACT_ALARM, which
        // Android 14+ gates behind a settings trip and Play Store review, to
        // buy precision this app does not need: a few minutes' slack on a
        // one-hour warning changes nothing.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: copy.title,
        body: copy.body,
      );
    }
  }

  static NotificationDetails _detailsFor(ReminderKind kind) => switch (kind) {
    ReminderKind.closing => const NotificationDetails(
      android: AndroidNotificationDetails(
        _closingChannelId,
        _closingChannelName,
        channelDescription: _closingChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: _accent,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    // Lower importance: reopening is good news, not something to interrupt
    // for. It still posts, it just does not push itself in front of you.
    ReminderKind.reopening => const NotificationDetails(
      android: AndroidNotificationDetails(
        _reopeningChannelId,
        _reopeningChannelName,
        channelDescription: _reopeningChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        color: _accent,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  };

  @override
  Future<void> cancelAll() async {
    if (!canSchedule) return;
    await initialize();
    await _plugin.cancelAll();
  }

  @override
  Future<int> pendingCount() async {
    if (!canSchedule) return 0;
    await initialize();
    return (await _plugin.pendingNotificationRequests()).length;
  }

  static NotificationPermission _fromBool(bool? granted) => switch (granted) {
    true => NotificationPermission.granted,
    false => NotificationPermission.denied,
    null => NotificationPermission.unknown,
  };
}

/// Used where notifications cannot work at all. Kept for tests and for any
/// future platform without support.
class UnsupportedNotificationService implements NotificationService {
  const UnsupportedNotificationService();

  @override
  bool get canSchedule => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermission> permission() async =>
      NotificationPermission.unknown;

  @override
  Future<NotificationPermission> requestPermission() async =>
      NotificationPermission.unknown;

  @override
  Future<void> schedule({
    required List<Reminder> reminders,
    required ReminderText text,
  }) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<int> pendingCount() async => 0;
}
