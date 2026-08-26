import 'package:flutter/foundation.dart';

import '../../data/repositories/closure_repository.dart';
import '../../data/services/alert_preferences_service.dart';
import '../../data/services/notification_service.dart';
import '../../domain/bridge_clock.dart';
import '../../domain/reminder_planner.dart';

/// Drives the Alerts screen: permission state, the on/off switch, the lead
/// time, and keeping the scheduled reminders in step with the feed.
class AlertsViewModel extends ChangeNotifier {
  AlertsViewModel({
    required this._notifications,
    required this._preferences,
    required this._repository,
    required this._clock,
  }) {
    _repository.addListener(_onClosuresChanged);
  }

  final NotificationService _notifications;
  final AlertPreferencesService _preferences;
  final ClosureRepository _repository;
  final BridgeClock _clock;

  /// Offered by the planner, so the list and the rules cannot disagree.
  static const List<Duration> leadTimeOptions =
      ReminderPlanner.leadTimeOptions;

  static const ReminderPlanner _planner = ReminderPlanner();

  AlertPreferences _prefs = AlertPreferences.defaults();
  NotificationPermission _permission = NotificationPermission.unknown;
  int _scheduled = 0;
  bool _busy = false;
  bool _loaded = false;

  /// Set by the view, so the notification copy can be localised without this
  /// view model depending on l10n. Re-set whenever the locale changes.
  ReminderText? _text;

  bool get canSchedule => _notifications.canSchedule;
  bool get enabled => _prefs.enabled;
  Set<Duration> get leadTimes => _prefs.leadTimes;
  NotificationPermission get permission => _permission;
  int get scheduledCount => _scheduled;
  bool get busy => _busy;
  bool get isLoaded => _loaded;

  /// True when the user wants alerts but the OS is refusing them. This is the
  /// state that needs explaining rather than a button.
  bool get blockedBySystem =>
      _prefs.enabled && _permission == NotificationPermission.denied;

  /// What would be scheduled right now, for display.
  List<Reminder> get planned => _planner.plan(
    closures: _repository.closures,
    now: _clock.now(),
    leadTimes: _prefs.leadTimes,
  );

  /// True when the selection produced more reminders than the OS will hold, so
  /// the list is the soonest ones rather than all of them.
  bool get truncated =>
      planned.length >= ReminderPlanner.maxReminders;

  void attachText(ReminderText text) => _text = text;

  Future<void> load() async {
    _prefs = await _preferences.read();
    _permission = await _notifications.permission();
    _scheduled = await _notifications.pendingCount();
    _loaded = true;
    notifyListeners();
    // Settings can be revoked while the app was closed, so what is actually
    // pending may not match what the user asked for.
    if (_prefs.enabled) await _reschedule();
  }

  /// Turning alerts on is what triggers the OS permission prompt.
  Future<void> setEnabled(bool value) async {
    // Nothing to enable where the platform cannot schedule. The UI hides the
    // control there, but the view model should not pretend either.
    if (_busy || !canSchedule) return;
    _busy = true;
    notifyListeners();
    try {
      if (value) {
        _permission = await _notifications.permission();
        if (_permission != NotificationPermission.granted) {
          _permission = await _notifications.requestPermission();
        }
        _prefs = _prefs.copyWith(enabled: true);
        await _preferences.write(_prefs);
        await _reschedule();
      } else {
        _prefs = _prefs.copyWith(enabled: false);
        await _preferences.write(_prefs);
        await _notifications.cancelAll();
        _scheduled = 0;
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Adds or removes one lead time.
  ///
  /// Removing the last one is ignored: alerts that are on but have no timing
  /// would schedule nothing while claiming to be active.
  Future<void> toggleLeadTime(Duration value) async {
    if (_busy) return;
    final Set<Duration> next = Set<Duration>.of(_prefs.leadTimes);
    if (next.contains(value)) {
      if (next.length == 1) return;
      next.remove(value);
    } else {
      next.add(value);
    }
    _prefs = _prefs.copyWith(leadTimes: next);
    await _preferences.write(_prefs);
    notifyListeners();
    if (_prefs.enabled) await _reschedule();
  }

  /// Re-checks permission, for when the user comes back from system settings.
  Future<void> refreshPermission() async {
    _permission = await _notifications.permission();
    notifyListeners();
    if (_prefs.enabled) await _reschedule();
  }

  Future<void> _reschedule() async {
    final ReminderText? text = _text;
    if (!canSchedule ||
        !_prefs.enabled ||
        text == null ||
        _permission != NotificationPermission.granted) {
      await _notifications.cancelAll();
      _scheduled = 0;
      notifyListeners();
      return;
    }
    await _notifications.schedule(reminders: planned, text: text);
    _scheduled = await _notifications.pendingCount();
    notifyListeners();
  }

  void _onClosuresChanged() {
    // The feed drives the reminders, so a refresh has to re-lay them.
    if (_prefs.enabled) _reschedule();
  }

  @override
  void dispose() {
    _repository.removeListener(_onClosuresChanged);
    super.dispose();
  }
}
