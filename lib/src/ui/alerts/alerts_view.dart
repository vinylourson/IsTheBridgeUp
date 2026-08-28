import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

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
    vm.attachText((Reminder reminder) {
      final tz.TZDateTime start = reminder.closure.start;
      final tz.TZDateTime firesAt = tz.TZDateTime.from(
        reminder.at,
        start.location,
      );
      // A day-ahead reminder has to name the day: "closes at 14:04" is
      // ambiguous when you are reading it the evening before. The day is
      // relative to when the notification fires, not to now.
      final bool sameDay =
          start.year == firesAt.year &&
          start.month == firesAt.month &&
          start.day == firesAt.day;

      if (reminder.kind == ReminderKind.reopening) {
        return (
          title: l10n.notificationReopenedTitle,
          body: l10n.notificationReopenedBody,
        );
      }

      final String time = Fmt.time(locale, start);
      return (
        title: sameDay
            ? l10n.notificationTitle(time)
            : l10n.notificationTitleOn(
                Fmt.day(l10n, locale, start, firesAt),
                time,
              ),
        body: reminder.closure.isMaintenance
            ? l10n.notificationBodyMaintenance(
                Fmt.time(locale, reminder.closure.end),
              )
            : l10n.notificationBody(
                reminder.closure.vessels.join(' · '),
                Fmt.time(locale, reminder.closure.end),
              ),
      );
    });

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
          _Reopening(vm: vm),
          const SizedBox(height: 12),
          _Upcoming(vm: vm, locale: locale),
          const SizedBox(height: 12),
          if (vm.truncated)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                l10n.alertsCapped(ReminderPlanner.maxReminders),
                style: PixelText.bodySmall.copyWith(
                  color: PixelPalette.warning,
                ),
              ),
            ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Several at once: a day-ahead heads-up and an hour-ahead warning
          // are useful for different reasons.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Duration lead in AlertsViewModel.leadTimeOptions)
                PixelButton(
                  label: Fmt.duration(l10n, lead),
                  selected: vm.leadTimes.contains(lead),
                  onPressed: vm.busy ? null : () => vm.toggleLeadTime(lead),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.alertsLeadTimeHint,
            style: PixelText.bodySmall.copyWith(color: PixelPalette.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// The other half of the question: not just when you cannot cross, but when
/// you can again.
class _Reopening extends StatelessWidget {
  const _Reopening({required this.vm});

  final AlertsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PixelButton(
            label: l10n.alertsReopening,
            selected: vm.notifyReopening,
            expand: true,
            onPressed: vm.busy
                ? null
                : () => vm.setNotifyReopening(!vm.notifyReopening),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.alertsReopeningHint,
            style: PixelText.bodySmall.copyWith(color: PixelPalette.inkFaint),
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

  /// "when it fires  >  which closure".
  ///
  /// The closure keeps its date only when it falls on a different day, which
  /// a day-ahead lead makes common: "17:49 > 17:49" reads like a mistake.
  static String _rowFor(
    Reminder reminder,
    String locale,
    AppLocalizations l10n,
  ) {
    final tz.TZDateTime start = reminder.closure.start;
    final tz.TZDateTime firesAt = tz.TZDateTime.from(
      reminder.at,
      start.location,
    );
    final bool sameDay =
        start.year == firesAt.year &&
        start.month == firesAt.month &&
        start.day == firesAt.day;
    if (reminder.kind == ReminderKind.reopening) {
      // Fires at the reopening itself, so there is no "warns about" target to
      // point at -- the arrow would point at its own timestamp.
      return '${Fmt.stamp(locale, firesAt)}  >  ${l10n.alertsRowReopens}';
    }
    final String target = sameDay
        ? Fmt.time(locale, start)
        : Fmt.stamp(locale, start);
    return '${Fmt.stamp(locale, firesAt)}  >  $target';
  }

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
                    child: Text(
                      _rowFor(reminder, locale, l10n),
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
