import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// One line of the home-screen widget, already formatted and translated.
class WidgetRow {
  const WidgetRow({required this.when, required this.what});

  /// Left column: when the closure is.
  final String when;

  /// Right column: what is passing, or that it is maintenance.
  final String what;
}

/// What the widget should display.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.status,
    required this.updated,
    required this.empty,
    required this.rows,
  });

  final String status;
  final String updated;

  /// Shown instead of the rows when there is nothing upcoming.
  final String empty;
  final List<WidgetRow> rows;
}

/// Pushes the schedule to the Android home-screen widget.
///
/// Everything handed over is a finished, localised string. The widget's Kotlin
/// side does no formatting at all — doing it there would mean a second
/// implementation of the app's date rules and translations, free to drift from
/// the tested one. Kotlin decides only how many rows fit.
class HomeWidgetService {
  const HomeWidgetService();

  /// Matches the provider class; home_widget needs it to target the update.
  static const String _androidProvider =
      'fr.vinylourson.is_the_bridge_up.BridgeWidgetProvider';

  /// The layout declares this many rows, so writing more would be pointless.
  static const int maxRows = 10;

  /// True only where a home-screen widget can exist.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> push(WidgetSnapshot snapshot) async {
    if (!isSupported) return;
    try {
      await _write(snapshot);
    } catch (error) {
      // A home-screen widget that fails to update is a cosmetic problem. It
      // must never take the app down with it, and on a device without the
      // plugin registered -- or in a widget test -- the channel simply is not
      // there.
      debugPrint('Home widget update skipped: $error');
    }
  }

  Future<void> _write(WidgetSnapshot snapshot) async {
    final List<WidgetRow> rows = snapshot.rows.take(maxRows).toList();
    await HomeWidget.saveWidgetData<String>('bridge.status', snapshot.status);
    await HomeWidget.saveWidgetData<String>('bridge.updated', snapshot.updated);
    await HomeWidget.saveWidgetData<String>('bridge.empty', snapshot.empty);
    await HomeWidget.saveWidgetData<int>('bridge.count', rows.length);

    for (int i = 0; i < maxRows; i++) {
      // Every slot is written every time, blanks included: leaving stale keys
      // behind would resurrect old closures the moment someone enlarges the
      // widget past the current row count.
      final WidgetRow? row = i < rows.length ? rows[i] : null;
      await HomeWidget.saveWidgetData<String>(
        'bridge.row$i.when',
        row?.when ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'bridge.row$i.what',
        row?.what ?? '',
      );
    }

    await HomeWidget.updateWidget(qualifiedAndroidName: _androidProvider);
  }
}
