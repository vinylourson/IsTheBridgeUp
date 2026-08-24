import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/services/notification_service.dart';
import '../../domain/reminder_planner.dart';
import '../format.dart';
import '../theme/palette.dart';
import '../theme/pixel_theme.dart';
import '../widgets/notice_strip.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_panel.dart';
import 'alerts_view_model.dart';

/// Reminder settings, and the only place that asks for notification
/// permission — the prompt appears when the user turns alerts on, not on
/// first launch where it would be refused before the app has explained itself.
class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AlertsViewModel vm = context.read<AlertsViewModel>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();

    // Re-attached on every locale change so a scheduled reminder is written in
    // the language the app is showing.
    vm.attachText(
      (Reminder reminder) => (
        title: l10n.notificationTitle(
          Fmt.time(locale, reminder.closure.start),
        ),
        body: reminder.closure.isMaintenance
            ? l10n.notificationBodyMaintenance(
                Fmt.time(locale, reminder.closure.end),
              )
            : l10n.notificationBody(
                reminder.closure.vessels.join(' · '),
                Fmt.time(locale, reminder.closure.end),
              ),
      ),
    );

    if (!_loadStarted) {
      _loadStarted = true;
      vm.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AlertsViewModel vm = context.watch<AlertsViewModel>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toLanguageTag();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Text(
          l10n.alertsTitle,
          style: PixelText.title.copyWith(color: PixelPalette.open),
        ),
        const SizedBox(height: 12),

        PixelPanel(
          child: Text(l10n.alertsExplain, style: PixelText.body),
        ),
        const SizedBox(height: 12),

        if (!vm.canSchedule)
          NoticeStrip(message: l10n.alertsWebNote)
        else ...<Widget>[
          _Switch(vm: vm),
          if (vm.blockedBySystem) ...<Widget>[
            const SizedBox(height: 12),
            NoticeStrip(message: l10n.alertsBlocked),
            const SizedBox(height: 10),
            PixelButton(
              label: l10n.alertsRecheck,
              onPressed: vm.refreshPermission,
            ),
          ],
          const SizedBox(height: 12),
          _LeadTime(vm: vm),
          const SizedBox(height: 12),
          _Upcoming(vm: vm, locale: locale),
          const SizedBox(height: 12),
          Text(
            l10n.alertsTimingNote,
            style: PixelText.bodySmall.copyWith(color: PixelPalette.inkFaint),
          ),
        ],
      ],
    );
  }
}

/// On/off, with the count the OS is actually holding.
class _Switch extends StatelessWidget {
  const _Switch({required this.vm});

  final AlertsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool on =
        vm.enabled && vm.permission == NotificationPermission.granted;
    final Color accent = on ? PixelPalette.open : PixelPalette.inkDim;

    return PixelPanel(
      borderColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            on ? l10n.alertsOn : l10n.alertsOff,
            // Silkscreen, not Press Start 2P: the latter squeezes accented
            // capitals into the unaccented letter's box, so "DÉSACTIVÉES"
            // came out with a stunted É. Same reason the verdict uses it.
            style: PixelText.data.copyWith(color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.alertsScheduled(on ? vm.scheduledCount : 0),
            style: PixelText.bodySmall.copyWith(color: PixelPalette.inkDim),
          ),
          const SizedBox(height: 14),
          PixelButton(
            label: vm.busy
                ? l10n.alertsAsking
                : on
                ? l10n.alertsDisable
                : l10n.alertsEnable,
            expand: true,
            accent: accent,
            onPressed: vm.busy ? null : () => vm.setEnabled(!on),
          ),
        ],
      ),
    );
  }
}

class _LeadTime extends StatelessWidget {
  const _LeadTime({required this.vm});

  final AlertsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PixelPanel(
      title: l10n.alertsLeadTime,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final Duration lead in AlertsViewModel.leadTimeOptions)
            PixelButton(
              label: Fmt.duration(l10n, lead),
              selected: lead == vm.leadTime,
              onPressed: vm.busy ? null : () => vm.setLeadTime(lead),
            ),
        ],
      ),
    );
  }
}

/// When the next few reminders would fire — so "alerts on" is verifiable
/// rather than a claim.
class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.vm, required this.locale});

  final AlertsViewModel vm;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<Reminder> planned = vm.planned;

    return PixelPanel(
      title: l10n.alertsNextReminders,
      child: planned.isEmpty
          ? Text(
              l10n.noUpcomingClosures,
              style: PixelText.bodySmall.copyWith(color: PixelPalette.inkDim),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final Reminder reminder in planned.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    // The reminder time, then the closure it warns about.
                    // Repeating the lead time on every row was just noise --
                    // it is already set in the panel above.
                    child: Text(
                      '${Fmt.stamp(locale, reminder.at)}'
                      '  >  ${Fmt.time(locale, reminder.closure.start)}',
                      style: PixelText.bodySmall.copyWith(
                        color: PixelPalette.inkDim,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
