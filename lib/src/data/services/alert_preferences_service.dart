import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../../domain/reminder_planner.dart';

/// The user's reminder settings.
class AlertPreferences {
  const AlertPreferences({required this.enabled, required this.leadTimes});

  /// Not const: Dart forbids const sets whose elements override `==`, and
  /// Duration does.
  factory AlertPreferences.defaults() => AlertPreferences(
    enabled: false,
    leadTimes: defaultLeadTimes,
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

  AlertPreferences copyWith({bool? enabled, Set<Duration>? leadTimes}) =>
      AlertPreferences(
        enabled: enabled ?? this.enabled,
        leadTimes: leadTimes ?? this.leadTimes,
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
    );
  }

  Future<void> write(AlertPreferences preferences) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(CacheKeys.alertsEnabled, preferences.enabled);
    await prefs.setStringList(
      CacheKeys.alertsLeadMinutes,
      preferences.leadTimes
          .map((Duration d) => d.inMinutes.toString())
          .toList(growable: false),
    );
  }
}
