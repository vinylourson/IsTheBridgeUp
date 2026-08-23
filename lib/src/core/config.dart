/// Static configuration for the Chaban-Delmas bridge data source.
///
/// The dataset is published by Bordeaux Métropole under the
/// Licence Ouverte / Open Licence. data.gouv.fr fronts it with a stable
/// permalink that 302-redirects to the OpenDataSoft Explore v2.1 API below;
/// we talk to the API directly because it accepts query parameters and
/// answers with `access-control-allow-origin: *` (so Flutter web needs no proxy).
class ApiConfig {
  const ApiConfig._();

  static const String host = 'datahub.bordeaux-metropole.fr';
  static const String datasetId = 'previsions_pont_chaban';

  /// Queryable records endpoint.
  static const String recordsPath =
      '/api/explore/v2.1/catalog/datasets/$datasetId/records';

  /// Stable data.gouv.fr permalink to the full JSON export. Used as a fallback
  /// if the datahub host ever moves; it takes no query parameters.
  static const String fallbackExportUrl =
      'https://www.data.gouv.fr/api/1/datasets/r/a0afdbe2-83a3-4bb2-9b17-ae19162e0255';

  /// Human-facing source page, linked from the Info screen.
  static const String sourcePageUrl =
      'https://www.data.gouv.fr/datasets/pont-chaban-previsions-fermeture-1';

  static const String attribution = 'Bordeaux Métropole';
  static const String licence = 'Licence Ouverte / Open Licence';

  /// The dataset holds fewer than 150 rows in practice; one page is plenty.
  static const int pageLimit = 100;
}

/// The bridge is in Bordeaux, so every wall-clock time in the feed is
/// Europe/Paris regardless of where the user or a CI runner happens to be.
const String bridgeTimeZone = 'Europe/Paris';

/// Keys for the offline snapshot in shared_preferences.
class CacheKeys {
  const CacheKeys._();
  static const String records = 'chaban.records.v1';
  static const String fetchedAt = 'chaban.fetchedAt.v1';
}
