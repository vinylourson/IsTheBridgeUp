import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../../domain/reminder_planner.dart';

/// The user's reminder settings.
class AlertPreferences {
  const AlertPreferences({
    required this.enabled,
    required this.leadTimes,
    required this.notifyReopening,
  });

  /// Not const: Dart forbids const sets whose elements override `==`, and
  /// Duration does.
  factory AlertPreferences.defaults() => AlertPreferences(
    enabled: false,
    leadTimes: defaultLeadTimes,
    // Off by default. It is the other half of the question, but switching it
    // on doubles the notification count and fires at the reopening whenever
    // that falls -- 05:00, for an overnight maintenance closure. Opting in to
    // that is the user's call, not a default.
    notifyReopening: false,
  );

  /// One hour ahead is the useful default: long enough to pick another route,
  /// short enough that the closure is still imminent.
  static Set<Duration> get defaultLeadTimes => <Duration>{
    const Duration(hours: 1),
  };

  final bool enabled;

  /// Several lead times can be active at once, so one closure can produce a
  /// day-ahead heads-up *and* an hour-ahead warning.
  final Set<Duration> leadTimes;

  /// Also notify at the moment the bridge reopens.
  final bool notifyReopening;

  AlertPreferences copyWith({
    bool? enabled,
    Set<Duration>? leadTimes,
    bool? notifyReopening,
  }) => AlertPreferences(
    enabled: enabled ?? this.enabled,
    leadTimes: leadTimes ?? this.leadTimes,
    notifyReopening: notifyReopening ?? this.notifyReopening,
  );
}

/// Persists the reminder settings across launches.
class AlertPreferencesService {
  Future<AlertPreferences> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? stored = prefs.getStringList(
      CacheKeys.alertsLeadMinutes,
    );

    Set<Duration> leadTimes = AlertPreferences.defaultLeadTimes;
    if (stored != null) {
      final Set<Duration> parsed = stored
          .map(int.tryParse)
          .whereType<int>()
          .map((int m) => Duration(minutes: m))
          // Drop anything no longer offered, so removing an option later does
          // not leave an unreachable value selected.
          .where(ReminderPlanner.leadTimeOptions.contains)
          .toSet();
      if (parsed.isNotEmpty) leadTimes = parsed;
    }

    return AlertPreferences(
      enabled: prefs.getBool(CacheKeys.alertsEnabled) ?? false,
      leadTimes: leadTimes,
      notifyReopening: prefs.getBool(CacheKeys.alertsReopening) ?? false,
    );
  }

  Future<void> write(AlertPreferences preferences) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(CacheKeys.alertsEnabled, preferences.enabled);
    await prefs.setBool(
      CacheKeys.alertsReopening,
      preferences.notifyReopening,
    );
    await prefs.setStringList(
      CacheKeys.alertsLeadMinutes,
      preferences.leadTimes
          .map((Duration d) => d.inMinutes.toString())
          .toList(growable: false),
    );
  }
}
