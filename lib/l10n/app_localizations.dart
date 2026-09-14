import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Is The Bridge Up?'**
  String get appTitle;

  /// No description provided for @bridgeName.
  ///
  /// In en, this message translates to:
  /// **'Chaban-Delmas Bridge'**
  String get bridgeName;

  /// No description provided for @bridgeCity.
  ///
  /// In en, this message translates to:
  /// **'Bordeaux'**
  String get bridgeCity;

  /// No description provided for @statusOpen.
  ///
  /// In en, this message translates to:
  /// **'BRIDGE OPEN'**
  String get statusOpen;

  /// No description provided for @statusClosed.
  ///
  /// In en, this message translates to:
  /// **'BRIDGE CLOSED'**
  String get statusClosed;

  /// No description provided for @statusUnknown.
  ///
  /// In en, this message translates to:
  /// **'NO DATA'**
  String get statusUnknown;

  /// No description provided for @youMayCross.
  ///
  /// In en, this message translates to:
  /// **'You may cross'**
  String get youMayCross;

  /// No description provided for @takeAnotherRoute.
  ///
  /// In en, this message translates to:
  /// **'Take another route'**
  String get takeAnotherRoute;

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'Could not load the schedule'**
  String get noDataYet;

  /// No description provided for @nextClosureIn.
  ///
  /// In en, this message translates to:
  /// **'Next closure in {duration}'**
  String nextClosureIn(String duration);

  /// No description provided for @reopensIn.
  ///
  /// In en, this message translates to:
  /// **'Reopens in {duration}'**
  String reopensIn(String duration);

  /// No description provided for @reopensAt.
  ///
  /// In en, this message translates to:
  /// **'Reopens at {time}'**
  String reopensAt(String time);

  /// No description provided for @noUpcomingClosures.
  ///
  /// In en, this message translates to:
  /// **'No closures scheduled'**
  String get noUpcomingClosures;

  /// No description provided for @closureWindow.
  ///
  /// In en, this message translates to:
  /// **'{start} > {end}'**
  String closureWindow(String start, String end);

  /// No description provided for @durationDay.
  ///
  /// In en, this message translates to:
  /// **'{value}d'**
  String durationDay(int value);

  /// No description provided for @durationHour.
  ///
  /// In en, this message translates to:
  /// **'{value}h'**
  String durationHour(int value);

  /// No description provided for @durationMinute.
  ///
  /// In en, this message translates to:
  /// **'{value}m'**
  String durationMinute(int value);

  /// No description provided for @durationLessThanAMinute.
  ///
  /// In en, this message translates to:
  /// **'under a minute'**
  String get durationLessThanAMinute;

  /// No description provided for @tabStatus.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get tabStatus;

  /// No description provided for @tabSchedule.
  ///
  /// In en, this message translates to:
  /// **'LIST'**
  String get tabSchedule;

  /// No description provided for @tabAlerts.
  ///
  /// In en, this message translates to:
  /// **'ALERTS'**
  String get tabAlerts;

  /// No description provided for @tabInfo.
  ///
  /// In en, this message translates to:
  /// **'INFO'**
  String get tabInfo;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Next lifts'**
  String get scheduleTitle;

  /// No description provided for @scheduleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled. The feed has no closures left.'**
  String get scheduleEmpty;

  /// No description provided for @maintenanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceLabel;

  /// No description provided for @todayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayLabel;

  /// No description provided for @tomorrowLabel.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrowLabel;

  /// No description provided for @overnightNote.
  ///
  /// In en, this message translates to:
  /// **'overnight'**
  String get overnightNote;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'{duration} closed'**
  String durationLabel(String duration);

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'IN PROGRESS'**
  String get inProgress;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAt(String time);

  /// No description provided for @offlineStale.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing data from {time}'**
  String offlineStale(String time);

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh. Showing saved data.'**
  String get refreshFailed;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @alertsLeadTime.
  ///
  /// In en, this message translates to:
  /// **'Warn me before a closure'**
  String get alertsLeadTime;

  /// No description provided for @infoTitle.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get infoTitle;

  /// No description provided for @infoWhat.
  ///
  /// In en, this message translates to:
  /// **'The Chaban-Delmas bridge lifts to let tall ships up the Garonne. When it does, the road is closed for around an hour and the detour is long. This app tells you whether you can cross.'**
  String get infoWhat;

  /// No description provided for @infoForecastCaveat.
  ///
  /// In en, this message translates to:
  /// **'These are forecasts published by Bordeaux Métropole, not a live sensor. Times can move, and a lift can be cancelled. Check before relying on it.'**
  String get infoForecastCaveat;

  /// No description provided for @infoTimesInParis.
  ///
  /// In en, this message translates to:
  /// **'All times are Bordeaux local time (Europe/Paris).'**
  String get infoTimesInParis;

  /// No description provided for @infoDataSource.
  ///
  /// In en, this message translates to:
  /// **'Data source'**
  String get infoDataSource;

  /// No description provided for @infoLicence.
  ///
  /// In en, this message translates to:
  /// **'Licence'**
  String get infoLicence;

  /// No description provided for @infoOpenSourcePage.
  ///
  /// In en, this message translates to:
  /// **'Open the dataset page'**
  String get infoOpenSourcePage;

  /// No description provided for @alertsExplain.
  ///
  /// In en, this message translates to:
  /// **'A reminder before each closure, so you can take another route instead of finding out at the barrier.'**
  String get alertsExplain;

  /// No description provided for @alertsEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn alerts on'**
  String get alertsEnable;

  /// No description provided for @alertsDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn alerts off'**
  String get alertsDisable;

  /// No description provided for @alertsOn.
  ///
  /// In en, this message translates to:
  /// **'ALERTS ON'**
  String get alertsOn;

  /// No description provided for @alertsOff.
  ///
  /// In en, this message translates to:
  /// **'ALERTS OFF'**
  String get alertsOff;

  /// No description provided for @alertsAsking.
  ///
  /// In en, this message translates to:
  /// **'Asking…'**
  String get alertsAsking;

  /// No description provided for @alertsBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked for this app. Turn them on in your device settings, then come back and tap Check again.'**
  String get alertsBlocked;

  /// No description provided for @alertsRecheck.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get alertsRecheck;

  /// No description provided for @alertsScheduled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No reminders scheduled} =1{1 reminder scheduled} other{{count} reminders scheduled}}'**
  String alertsScheduled(int count);

  /// No description provided for @alertsNextReminders.
  ///
  /// In en, this message translates to:
  /// **'Next reminders'**
  String get alertsNextReminders;

  /// No description provided for @alertsTimingNote.
  ///
  /// In en, this message translates to:
  /// **'Delivery can be a few minutes late: the app asks for a battery-friendly alarm rather than an exact one.'**
  String get alertsTimingNote;

  /// No description provided for @alertsWebNote.
  ///
  /// In en, this message translates to:
  /// **'A browser cannot post a reminder once its tab is closed, so alerts need the Android or iOS app.'**
  String get alertsWebNote;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Bridge closes at {time}'**
  String notificationTitle(String time);

  /// No description provided for @notificationBody.
  ///
  /// In en, this message translates to:
  /// **'{vessel} · closed until {end}. Take another route.'**
  String notificationBody(String vessel, String end);

  /// No description provided for @notificationBodyMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance · closed until {end}. Take another route.'**
  String notificationBodyMaintenance(String end);

  /// No description provided for @alertsLeadTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Pick as many as you like — one closure can warn you a day ahead and again on the hour. At least one stays selected.'**
  String get alertsLeadTimeHint;

  /// No description provided for @alertsCapped.
  ///
  /// In en, this message translates to:
  /// **'Only the soonest {count} reminders fit; your device limits how many can be pending at once.'**
  String alertsCapped(int count);

  /// No description provided for @notificationTitleOn.
  ///
  /// In en, this message translates to:
  /// **'Bridge closes {day} at {time}'**
  String notificationTitleOn(String day, String time);

  /// No description provided for @alertsReopening.
  ///
  /// In en, this message translates to:
  /// **'Tell me when it reopens'**
  String get alertsReopening;

  /// No description provided for @alertsReopeningHint.
  ///
  /// In en, this message translates to:
  /// **'A second notification the moment the bridge is back open, so you know when to set off.'**
  String get alertsReopeningHint;

  /// No description provided for @notificationReopenedTitle.
  ///
  /// In en, this message translates to:
  /// **'Bridge reopened'**
  String get notificationReopenedTitle;

  /// No description provided for @notificationReopenedBody.
  ///
  /// In en, this message translates to:
  /// **'You can cross again.'**
  String get notificationReopenedBody;

  /// No description provided for @alertsRowReopens.
  ///
  /// In en, this message translates to:
  /// **'REOPENS'**
  String get alertsRowReopens;

  /// No description provided for @infoVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get infoVersion;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
