import 'package:timezone/timezone.dart' as tz;

/// One scheduled closure of the Chaban-Delmas bridge to road traffic.
///
/// [start] and [end] are absolute instants resolved in the bridge's own time
/// zone (Europe/Paris), so comparisons are unambiguous wherever the app runs.
class Closure {
  const Closure({
    required this.vesselLabel,
    required this.start,
    required this.end,
    required this.closureType,
    required this.isTotal,
  });

  /// Raw `bateau` value. May name several vessels joined by ' - ', or be
  /// the literal 'MAINTENANCE' when no boat is involved.
  final String vesselLabel;

  final tz.TZDateTime start;
  final tz.TZDateTime end;

  /// Raw `type_de_fermeture`, e.g. 'Totale'.
  final String closureType;

  /// Whether the bridge is fully closed to traffic (`fermeture_totale == 'oui'`).
  final bool isTotal;

  Duration get duration => end.difference(start);

  /// Maintenance windows block traffic exactly like a boat passage, but they
  /// are labelled and illustrated differently.
  bool get isMaintenance => vesselLabel.trim().toUpperCase() == 'MAINTENANCE';

  /// Individual vessel names. Empty for maintenance windows.
  List<String> get vessels => isMaintenance
      ? const []
      : vesselLabel
            .split(' - ')
            .map((String v) => v.trim())
            .where((String v) => v.isNotEmpty)
            .toList(growable: false);

  /// True when [instant] falls inside the closure. The start is inclusive and
  /// the end exclusive, so the bridge counts as open the moment it reopens.
  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);

  /// True when the closure spans midnight, e.g. 23:00 -> 05:00.
  bool get isOvernight => start.day != end.day;

  @override
  String toString() =>
      'Closure($vesselLabel, ${start.toIso8601String()} -> ${end.toIso8601String()})';

  @override
  bool operator ==(Object other) =>
      other is Closure &&
      other.vesselLabel == vesselLabel &&
      other.start == start &&
      other.end == end &&
      other.closureType == closureType &&
      other.isTotal == isTotal;

  @override
  int get hashCode =>
      Object.hash(vesselLabel, start, end, closureType, isTotal);
}
