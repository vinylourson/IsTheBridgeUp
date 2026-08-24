import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'src/app.dart';
import 'src/core/config.dart';
import 'src/data/repositories/closure_repository.dart';
import 'src/data/services/alert_preferences_service.dart';
import 'src/data/services/chaban_api_service.dart';
import 'src/data/services/closure_cache_service.dart';
import 'src/data/services/notification_service.dart';
import 'src/domain/bridge_clock.dart';
import 'src/ui/alerts/alerts_view_model.dart';
import 'src/ui/status/status_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the tz database and pin everything to the bridge's own zone, so the
  // app is correct regardless of where the device thinks it is.
  tzdata.initializeTimeZones();
  final BridgeClock clock = BridgeClock(tz.getLocation(bridgeTimeZone));

  final ClosureRepository repository = ClosureRepository(
    api: ChabanApiService(),
    cache: ClosureCacheService(),
    clock: clock,
  );

  // Real notifications on Android and iOS. The service reports canSchedule
  // false on web, where the plugin builds but zonedSchedule throws: a browser
  // cannot run code to post a reminder once its tab is closed.
  final NotificationService notifications = LocalNotificationService();
  final AlertPreferencesService alertPreferences = AlertPreferencesService();

  runApp(
    MultiProvider(
      providers: [
        Provider<BridgeClock>.value(value: clock),
        Provider<NotificationService>.value(value: notifications),
        ChangeNotifierProvider<ClosureRepository>.value(value: repository),
        ChangeNotifierProvider<StatusViewModel>(
          create: (_) =>
              StatusViewModel(repository: repository, clock: clock),
        ),
        ChangeNotifierProvider<AlertsViewModel>(
          create: (_) => AlertsViewModel(
            notifications: notifications,
            preferences: alertPreferences,
            repository: repository,
            clock: clock,
          ),
        ),
      ],
      child: const IsTheBridgeUpApp(),
    ),
  );

  // Kick off cache-then-network after the first frame so the UI is never
  // blocked on I/O.
  repository.load();
}
