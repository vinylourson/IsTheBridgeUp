import 'ui/home_widget_snapshot.dart';
import 'data/services/home_widget_service.dart';
import 'data/repositories/closure_repository.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import 'core/config.dart';
import 'ui/alerts/alerts_view.dart';
import 'ui/format.dart';
import 'ui/info/info_view.dart';
import 'ui/schedule/schedule_view.dart';
import 'ui/status/status_view.dart';
import 'ui/status/status_view_model.dart';
import 'ui/theme/palette.dart';
import 'ui/theme/pixel_theme.dart';
import 'ui/widgets/pixel_button.dart';

class IsTheBridgeUpApp extends StatelessWidget {
  const IsTheBridgeUpApp({super.key, this.locale});

  /// Forces a locale instead of following the device. Used by tests, and
  /// available if a language switcher is ever added.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildPixelTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _Shell(),
    );
  }
}

/// Header, tabbed body, bottom navigation.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  static const HomeWidgetService _homeWidget = HomeWidgetService();

  /// Held rather than looked up again in dispose(): by then the element is
  /// deactivated and an ancestor lookup throws.
  ClosureRepository? _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_homeWidget.isSupported) return;
    if (_repository == null) {
      _repository = context.read<ClosureRepository>();
      _repository!.addListener(_pushToHomeWidget);
    }
    // Also on locale change: the widget holds finished strings, so it would
    // otherwise keep yesterday's language until the next refresh.
    _pushToHomeWidget();
  }

  @override
  void dispose() {
    _repository?.removeListener(_pushToHomeWidget);
    super.dispose();
  }

  /// Hands the home-screen widget a set of finished, translated strings.
  void _pushToHomeWidget() {
    if (!mounted) return;
    final StatusViewModel status = context.read<StatusViewModel>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final DateTime? fetchedAt = status.fetchedAt;

    unawaited(
      _homeWidget.push(
        buildWidgetSnapshot(
          l10n: l10n,
          locale: locale,
          status: status.status,
          upcoming: status.upcoming,
          now: status.now,
          fetchedAt: fetchedAt,
        ),
      ),
    );
  }

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    final List<(String label, Widget view)> tabs = <(String, Widget)>[
      (l10n.tabStatus, const StatusView()),
      (l10n.tabSchedule, const ScheduleView()),
      (l10n.tabAlerts, const AlertsView()),
      (l10n.tabInfo, const InfoView()),
    ];

    return Scaffold(
      backgroundColor: PixelPalette.background,
      body: SafeArea(
        child: Center(
          // The layout is phone-shaped; on a wide browser window it stays a
          // readable column rather than stretching the pixel art to bits.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: <Widget>[
                const _Header(),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    sizing: StackFit.expand,
                    children: <Widget>[
                      for (final (String _, Widget view) in tabs) view,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                  child: Row(
                    children: <Widget>[
                      for (int i = 0; i < tabs.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: PixelButton(
                            label: tabs[i].$1,
                            expand: true,
                            compact: true,
                            selected: i == _index,
                            onPressed: () => setState(() => _index = i),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Title strip with a live Bordeaux clock, like a status bar.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final tz.TZDateTime now = context.select<StatusViewModel, DateTime>(
      (StatusViewModel vm) => vm.now,
    ) as tz.TZDateTime;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PixelPalette.panelBorder, width: 2),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.appTitle,
                  style: PixelText.appName.copyWith(color: PixelPalette.open),
                  maxLines: 2,
                ),
                const SizedBox(height: 5),
                Text(
                  '${l10n.bridgeName} · ${l10n.bridgeCity}',
                  style: PixelText.bodySmall.copyWith(
                    color: PixelPalette.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Fmt.time(locale, now),
            style: PixelText.data.copyWith(color: PixelPalette.inkDim),
            semanticsLabel: '${Fmt.time(locale, now)} $bridgeTimeZone',
          ),
        ],
      ),
    );
  }
}
