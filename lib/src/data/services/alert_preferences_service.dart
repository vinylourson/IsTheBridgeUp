import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';

/// The user's reminder settings.
class AlertPreferences {
  const AlertPreferences({required this.enabled, required this.leadTime});

  const AlertPreferences.defaults()
    : enabled = false,
      leadTime = const Duration(hours: 1);

  final bool enabled;
  final Duration leadTime;

  AlertPreferences copyWith({bool? enabled, Duration? leadTime}) =>
      AlertPreferences(
        enabled: enabled ?? this.enabled,
        leadTime: leadTime ?? this.leadTime,
      );
}

/// Persists the reminder settings across launches.
class AlertPreferencesService {
  Future<AlertPreferences> read() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? minutes = prefs.getInt(CacheKeys.alertsLeadMinutes);
    return AlertPreferences(
      enabled: prefs.getBool(CacheKeys.alertsEnabled) ?? false,
      leadTime: minutes == null
          ? const Duration(hours: 1)
          : Duration(minutes: minutes),
    );
  }

  Future<void> write(AlertPreferences preferences) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(CacheKeys.alertsEnabled, preferences.enabled);
    await prefs.setInt(
      CacheKeys.alertsLeadMinutes,
      preferences.leadTime.inMinutes,
    );
  }
}
