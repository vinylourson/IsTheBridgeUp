import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:is_the_bridge_up/l10n/app_localizations.dart';
import 'package:is_the_bridge_up/src/data/services/home_widget_service.dart';
import 'package:is_the_bridge_up/src/domain/models/bridge_status.dart';
import 'package:is_the_bridge_up/src/domain/models/closure.dart';
import 'package:is_the_bridge_up/src/ui/home_widget_snapshot.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location paris;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tzdata.initializeTimeZones();
    paris = tz.getLocation('Europe/Paris');
    // Fmt uses DateFormat, which needs its locale data loaded first.
    await initializeDateFormatting('en');
    await initializeDateFormatting('fr');
  });

  tz.TZDateTime at(int day, int hour, [int minute = 0]) =>
      tz.TZDateTime(paris, 2026, 8, day, hour, minute);

  Closure closure(int day, int h1, int h2, String vessel) => Closure(
    vesselLabel: vessel,
    start: at(day, h1),
    end: at(day, h2),
    closureType: 'Totale',
    isTotal: true,
  );

  Future<AppLocalizations> l10nFor(String code) =>
      AppLocalizations.delegate.load(Locale(code));

  test('rows carry a formatted window and what is passing', () async {
    final AppLocalizations l10n = await l10nFor('en');
    final WidgetSnapshot snap = buildWidgetSnapshot(
      l10n: l10n,
      locale: 'en',
      status: BridgeOpen(nextClosure: closure(23, 14, 15, 'MV DEUTSCHLAND')),
      upcoming: <Closure>[closure(23, 14, 15, 'MV DEUTSCHLAND')],
      now: at(23, 8),
      fetchedAt: at(23, 7, 55),
    );

    expect(snap.status, l10n.statusOpen);
    expect(snap.rows, hasLength(1));
    expect(snap.rows.single.when, contains('14:00'));
    expect(snap.rows.single.when, contains('15:00'));
    expect(snap.rows.single.what, 'MV DEUTSCHLAND');
    expect(snap.updated, isNotEmpty);
  });

  test('maintenance is labelled, not left blank', () async {
    final AppLocalizations l10n = await l10nFor('en');
    final WidgetSnapshot snap = buildWidgetSnapshot(
      l10n: l10n,
      locale: 'en',
      status: BridgeOpen(nextClosure: closure(23, 23, 5, 'MAINTENANCE')),
      upcoming: <Closure>[closure(23, 23, 5, 'MAINTENANCE')],
      now: at(23, 8),
      fetchedAt: at(23, 7),
    );
    // A closure with no vessel would otherwise render an empty right column.
    expect(snap.rows.single.what, l10n.maintenanceLabel);
  });

  test('the closed state says so, in French too', () async {
    final AppLocalizations fr = await l10nFor('fr');
    final Closure current = closure(23, 14, 15, 'MV DEUTSCHLAND');
    final WidgetSnapshot snap = buildWidgetSnapshot(
      l10n: fr,
      locale: 'fr',
      status: BridgeClosed(current: current),
      upcoming: <Closure>[current],
      now: at(23, 14, 30),
      fetchedAt: at(23, 14),
    );
    expect(snap.status, fr.statusClosed);
    expect(snap.empty, fr.noUpcomingClosures);
  });

  test('never hands over more rows than the layout declares', () async {
    final AppLocalizations l10n = await l10nFor('en');
    final WidgetSnapshot snap = buildWidgetSnapshot(
      l10n: l10n,
      locale: 'en',
      status: const BridgeOpen(),
      upcoming: <Closure>[
        for (int d = 1; d <= 20; d++) closure(d, 9, 10, 'BOAT $d'),
      ],
      now: at(1, 0),
      fetchedAt: at(1, 0),
    );
    expect(snap.rows, hasLength(HomeWidgetService.maxRows));
  });

  test('an empty feed produces no rows but keeps the empty message', () async {
    final AppLocalizations l10n = await l10nFor('en');
    final WidgetSnapshot snap = buildWidgetSnapshot(
      l10n: l10n,
      locale: 'en',
      status: const BridgeOpen(),
      upcoming: const <Closure>[],
      now: at(23, 8),
      fetchedAt: null,
    );
    expect(snap.rows, isEmpty);
    expect(snap.empty, isNotEmpty);
    expect(snap.updated, isEmpty, reason: 'never fetched');
  });

  group('push', () {
    final List<MethodCall> calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('home_widget'),
            (MethodCall call) async {
              calls.add(call);
              return true;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('home_widget'),
            null,
          );
    });

    test('writes every row slot, blanks included', () async {
      // Reset inline rather than via addTearDown: the framework asserts that
      // foundation debug vars are clear before tearDown callbacks run.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final AppLocalizations l10n = await l10nFor('en');
      await const HomeWidgetService().push(
        buildWidgetSnapshot(
          l10n: l10n,
          locale: 'en',
          status: const BridgeOpen(),
          upcoming: <Closure>[closure(23, 14, 15, 'A')],
          now: at(23, 8),
          fetchedAt: at(23, 7),
        ),
      );
      debugDefaultTargetPlatformOverride = null;

      final Set<String> keys = calls
          .where((MethodCall c) => c.method == 'saveWidgetData')
          .map((MethodCall c) => (c.arguments as Map<Object?, Object?>)['id']!)
          .cast<String>()
          .toSet();

      // Slots past the end must still be written: leaving stale keys behind
      // resurrects old closures the moment the widget is made taller.
      for (int i = 0; i < HomeWidgetService.maxRows; i++) {
        expect(keys, contains('bridge.row$i.when'));
        expect(keys, contains('bridge.row$i.what'));
      }
      expect(keys, contains('bridge.count'));
      expect(
        calls.any((MethodCall c) => c.method == 'updateWidget'),
        isTrue,
        reason: 'saving without updating leaves the widget stale',
      );
    });
  });
}
