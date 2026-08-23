import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations.dart';
import '../../domain/models/bridge_status.dart';
import '../../domain/models/closure.dart';
import '../format.dart';
import '../theme/palette.dart';
import '../theme/pixel_theme.dart';
import '../widgets/bridge_scene.dart';
import '../widgets/closure_card.dart';
import '../widgets/countdown_bar.dart';
import '../widgets/notice_strip.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_panel.dart';
import 'status_view_model.dart';

/// The screen that answers the only question that matters: can I cross?
class StatusView extends StatelessWidget {
  const StatusView({super.key});

  @override
  Widget build(BuildContext context) {
    final StatusViewModel vm = context.watch<StatusViewModel>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final BridgeStatus status = vm.status;
    final tz.TZDateTime now = vm.now as tz.TZDateTime;

    final bool closed = status is BridgeClosed;
    final Closure? current = closed ? status.current : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        BridgeScene(
          raised: closed,
          maintenance: current?.isMaintenance ?? false,
        ),
        const SizedBox(height: 16),

        if (vm.isBlank)
          _BlankState(onRetry: vm.refresh)
        else ...<Widget>[
          _Verdict(status: status, now: now),
          const SizedBox(height: 12),
          if (status is BridgeClosed)
            _ClosedDetail(status: status, now: now)
          else if (status is BridgeOpen)
            _OpenDetail(status: status, now: now),
        ],

        const SizedBox(height: 16),
        if (vm.error != null && vm.hasData)
          NoticeStrip(message: l10n.refreshFailed)
        else if (vm.isStale && vm.fetchedAt != null)
          NoticeStrip(
            message: l10n.offlineStale(Fmt.stamp(locale, vm.fetchedAt!)),
          )
        else if (vm.fetchedAt != null)
          Text(
            l10n.updatedAt(Fmt.stamp(locale, vm.fetchedAt!)),
            style: PixelText.bodySmall.copyWith(color: PixelPalette.inkFaint),
          ),

        const SizedBox(height: 12),
        PixelButton(
          label: vm.isRefreshing ? l10n.loading : l10n.refresh,
          expand: true,
          onPressed: vm.isRefreshing ? null : vm.refresh,
        ),
      ],
    );
  }
}

/// The big OPEN / CLOSED verdict.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.status, required this.now});

  final BridgeStatus status;
  final tz.TZDateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool closed = status is BridgeClosed;
    final Color accent = closed ? PixelPalette.closed : PixelPalette.open;

    return PixelPanel(
      borderColor: accent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            closed ? l10n.statusClosed : l10n.statusOpen,
            style: PixelText.verdict.copyWith(color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            closed ? l10n.takeAnotherRoute : l10n.youMayCross,
            style: PixelText.body.copyWith(color: PixelPalette.ink),
          ),
        ],
      ),
    );
  }
}

/// While closed: how long until traffic resumes.
class _ClosedDetail extends StatelessWidget {
  const _ClosedDetail({required this.status, required this.now});

  final BridgeClosed status;
  final tz.TZDateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PixelPanel(
          title: l10n.reopensAt(Fmt.time(locale, status.current.end)),
          borderColor: PixelPalette.closed,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.reopensIn(
                  Fmt.duration(l10n, status.timeUntilReopen(now)),
                ),
                style: PixelText.dataLarge.copyWith(color: PixelPalette.ink),
              ),
              const SizedBox(height: 12),
              CountdownBar(
                progress: status.progress(now),
                color: PixelPalette.closed,
                semanticLabel: l10n.reopensAt(
                  Fmt.time(locale, status.current.end),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClosureCard(closure: status.current, now: now, highlight: true),
      ],
    );
  }
}

/// While open: what is coming next.
class _OpenDetail extends StatelessWidget {
  const _OpenDetail({required this.status, required this.now});

  final BridgeOpen status;
  final tz.TZDateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Closure? next = status.nextClosure;

    if (next == null) {
      return PixelPanel(
        child: Text(
          l10n.noUpcomingClosures,
          style: PixelText.body.copyWith(color: PixelPalette.inkDim),
        ),
      );
    }

    final Duration until = status.timeUntilClosure(now)!;
    // Fill the bar over the last 24 hours before a closure, so it becomes
    // meaningful exactly when it starts to matter.
    const Duration horizon = Duration(hours: 24);
    final double progress =
        1 - (until.inSeconds / horizon.inSeconds).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PixelPanel(
          borderColor: PixelPalette.open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.nextClosureIn(Fmt.duration(l10n, until)),
                style: PixelText.data.copyWith(color: PixelPalette.ink),
              ),
              if (until <= horizon) ...<Widget>[
                const SizedBox(height: 12),
                CountdownBar(
                  progress: progress,
                  color: PixelPalette.warning,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClosureCard(closure: next, now: now),
      ],
    );
  }
}

/// Nothing cached and the fetch failed.
class _BlankState extends StatelessWidget {
  const _BlankState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PixelPanel(
      borderColor: PixelPalette.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.statusUnknown,
            style: PixelText.title.copyWith(color: PixelPalette.warning),
          ),
          const SizedBox(height: 10),
          Text(l10n.noDataYet, style: PixelText.body),
          const SizedBox(height: 14),
          PixelButton(label: l10n.retry, onPressed: onRetry),
        ],
      ),
    );
  }
}
