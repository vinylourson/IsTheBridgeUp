// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Le pont est-il levé ?';

  @override
  String get bridgeName => 'Pont Chaban-Delmas';

  @override
  String get bridgeCity => 'Bordeaux';

  @override
  String get statusOpen => 'PONT OUVERT';

  @override
  String get statusClosed => 'PONT FERMÉ';

  @override
  String get statusUnknown => 'PAS DE DONNÉES';

  @override
  String get youMayCross => 'Vous pouvez passer';

  @override
  String get takeAnotherRoute => 'Prenez un autre itinéraire';

  @override
  String get noDataYet => 'Impossible de charger les horaires';

  @override
  String nextClosureIn(String duration) {
    return 'Prochaine fermeture dans $duration';
  }

  @override
  String reopensIn(String duration) {
    return 'Réouverture dans $duration';
  }

  @override
  String reopensAt(String time) {
    return 'Réouverture à $time';
  }

  @override
  String get noUpcomingClosures => 'Aucune fermeture prévue';

  @override
  String closureWindow(String start, String end) {
    return '$start > $end';
  }

  @override
  String durationDay(int value) {
    return '${value}j';
  }

  @override
  String durationHour(int value) {
    return '${value}h';
  }

  @override
  String durationMinute(int value) {
    return '${value}min';
  }

  @override
  String get durationLessThanAMinute => 'moins d\'une minute';

  @override
  String get tabStatus => 'ÉTAT';

  @override
  String get tabSchedule => 'LISTE';

  @override
  String get tabAlerts => 'ALERTES';

  @override
  String get tabInfo => 'INFOS';

  @override
  String get scheduleTitle => 'Prochaines levées';

  @override
  String get scheduleEmpty =>
      'Rien de prévu. Le jeu de données ne contient plus de fermeture.';

  @override
  String get maintenanceLabel => 'Maintenance';

  @override
  String get todayLabel => 'Aujourd\'hui';

  @override
  String get tomorrowLabel => 'Demain';

  @override
  String get overnightNote => 'de nuit';

  @override
  String durationLabel(String duration) {
    return '$duration de fermeture';
  }

  @override
  String get inProgress => 'EN COURS';

  @override
  String get refresh => 'Actualiser';

  @override
  String get retry => 'Réessayer';

  @override
  String get loading => 'Chargement…';

  @override
  String updatedAt(String time) {
    return 'Mis à jour $time';
  }

  @override
  String offlineStale(String time) {
    return 'Hors ligne — données du $time';
  }

  @override
  String get refreshFailed =>
      'Actualisation impossible. Données enregistrées affichées.';

  @override
  String get alertsTitle => 'Alertes';

  @override
  String get alertsUnavailableOnWeb =>
      'Les alertes nécessitent l\'application mobile. La version web ne peut pas programmer de rappels.';

  @override
  String get alertsLeadTime => 'M\'avertir avant une fermeture';

  @override
  String get infoTitle => 'Infos';

  @override
  String get infoWhat =>
      'Le pont Chaban-Delmas se lève pour laisser passer les grands navires sur la Garonne. La circulation est alors coupée pendant environ une heure, et le détour est long. Cette application vous dit si vous pouvez passer.';

  @override
  String get infoForecastCaveat =>
      'Ce sont des prévisions publiées par Bordeaux Métropole, pas un capteur en temps réel. Les horaires peuvent changer et une levée peut être annulée. Vérifiez avant de vous y fier.';

  @override
  String get infoTimesInParis =>
      'Toutes les heures sont à l\'heure locale de Bordeaux (Europe/Paris).';

  @override
  String get infoDataSource => 'Source des données';

  @override
  String get infoLicence => 'Licence';

  @override
  String get infoOpenSourcePage => 'Ouvrir la page du jeu de données';
}
