// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Is The Bridge Up?';

  @override
  String get bridgeName => 'Chaban-Delmas Bridge';

  @override
  String get bridgeCity => 'Bordeaux';

  @override
  String get statusOpen => 'BRIDGE OPEN';

  @override
  String get statusClosed => 'BRIDGE CLOSED';

  @override
  String get statusUnknown => 'NO DATA';

  @override
  String get youMayCross => 'You may cross';

  @override
  String get takeAnotherRoute => 'Take another route';

  @override
  String get noDataYet => 'Could not load the schedule';

  @override
  String nextClosureIn(String duration) {
    return 'Next closure in $duration';
  }

  @override
  String reopensIn(String duration) {
    return 'Reopens in $duration';
  }

  @override
  String reopensAt(String time) {
    return 'Reopens at $time';
  }

  @override
  String get noUpcomingClosures => 'No closures scheduled';

  @override
  String closureWindow(String start, String end) {
    return '$start > $end';
  }

  @override
  String durationDay(int value) {
    return '${value}d';
  }

  @override
  String durationHour(int value) {
    return '${value}h';
  }

  @override
  String durationMinute(int value) {
    return '${value}m';
  }

  @override
  String get durationLessThanAMinute => 'under a minute';

  @override
  String get tabStatus => 'STATUS';

  @override
  String get tabSchedule => 'LIST';

  @override
  String get tabAlerts => 'ALERTS';

  @override
  String get tabInfo => 'INFO';

  @override
  String get scheduleTitle => 'Next lifts';

  @override
  String get scheduleEmpty =>
      'Nothing scheduled. The feed has no closures left.';

  @override
  String get maintenanceLabel => 'Maintenance';

  @override
  String get todayLabel => 'Today';

  @override
  String get tomorrowLabel => 'Tomorrow';

  @override
  String get overnightNote => 'overnight';

  @override
  String durationLabel(String duration) {
    return '$duration closed';
  }

  @override
  String get inProgress => 'IN PROGRESS';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading…';

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String offlineStale(String time) {
    return 'Offline — showing data from $time';
  }

  @override
  String get refreshFailed => 'Could not refresh. Showing saved data.';

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get alertsLeadTime => 'Warn me before a closure';

  @override
  String get infoTitle => 'Info';

  @override
  String get infoWhat =>
      'The Chaban-Delmas bridge lifts to let tall ships up the Garonne. When it does, the road is closed for around an hour and the detour is long. This app tells you whether you can cross.';

  @override
  String get infoForecastCaveat =>
      'These are forecasts published by Bordeaux Métropole, not a live sensor. Times can move, and a lift can be cancelled. Check before relying on it.';

  @override
  String get infoTimesInParis =>
      'All times are Bordeaux local time (Europe/Paris).';

  @override
  String get infoDataSource => 'Data source';

  @override
  String get infoLicence => 'Licence';

  @override
  String get infoOpenSourcePage => 'Open the dataset page';

  @override
  String get alertsExplain =>
      'A reminder before each closure, so you can take another route instead of finding out at the barrier.';

  @override
  String get alertsEnable => 'Turn alerts on';

  @override
  String get alertsDisable => 'Turn alerts off';

  @override
  String get alertsOn => 'ALERTS ON';

  @override
  String get alertsOff => 'ALERTS OFF';

  @override
  String get alertsAsking => 'Asking…';

  @override
  String get alertsBlocked =>
      'Notifications are blocked for this app. Turn them on in your device settings, then come back and tap Check again.';

  @override
  String get alertsRecheck => 'Check again';

  @override
  String alertsScheduled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders scheduled',
      one: '1 reminder scheduled',
      zero: 'No reminders scheduled',
    );
    return '$_temp0';
  }

  @override
  String get alertsNextReminders => 'Next reminders';

  @override
  String get alertsTimingNote =>
      'Delivery can be a few minutes late: the app asks for a battery-friendly alarm rather than an exact one.';

  @override
  String get alertsWebNote =>
      'A browser cannot post a reminder once its tab is closed, so alerts need the Android or iOS app.';

  @override
  String notificationTitle(String time) {
    return 'Bridge closes at $time';
  }

  @override
  String notificationBody(String vessel, String end) {
    return '$vessel · closed until $end. Take another route.';
  }

  @override
  String notificationBodyMaintenance(String end) {
    return 'Maintenance · closed until $end. Take another route.';
  }

  @override
  String get alertsLeadTimeHint =>
      'Pick as many as you like — one closure can warn you a day ahead and again on the hour. At least one stays selected.';

  @override
  String alertsCapped(int count) {
    return 'Only the soonest $count reminders fit; your device limits how many can be pending at once.';
  }

  @override
  String notificationTitleOn(String day, String time) {
    return 'Bridge closes $day at $time';
  }

  @override
  String get alertsReopening => 'Tell me when it reopens';

  @override
  String get alertsReopeningHint =>
      'A second notification the moment the bridge is back open, so you know when to set off.';

  @override
  String get notificationReopenedTitle => 'Bridge reopened';

  @override
  String get notificationReopenedBody => 'You can cross again.';

  @override
  String get alertsRowReopens => 'REOPENS';
}
