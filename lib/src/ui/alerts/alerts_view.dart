import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../data/services/notification_service.dart';
import '../../domain/reminder_planner.dart';
import '../format.dart';
import '../status/status_view_model.dart';
import '../theme/palette.dart';
import '../theme/pixel_theme.dart';
import '../widgets/notice_strip.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_panel.dart';

/// Reminder settings.
///
/// On web there is nothing to switch on, so the screen says why and shows what
/// the planner *would* schedule — the logic is done, only delivery is not.
class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  static const List<Duration> _leadTimes = <Duration>[
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
  ];

  Duration _leadTime = const Duration(hours: 1);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StatusViewModel vm = context.watch<StatusViewModel>();
    final NotificationService notifications = context.read<NotificationService>();
    final List<Reminder> planned = const ReminderPlanner().plan(
      closures: vm.upcoming,
      now: vm.now,
      leadTime: _leadTime,
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Text(
          l10n.alertsTitle,
          style: PixelText.title.copyWith(color: PixelPalette.open),
        ),
        const SizedBox(height: 12),

        if (!notifications.isSupported)
          NoticeStrip(message: l10n.alertsUnavailableOnWeb),
        const SizedBox(height: 12),

        PixelPanel(
          title: l10n.alertsLeadTime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final Duration lead in _leadTimes)
                    PixelButton(
                      label: Fmt.duration(l10n, lead),
                      selected: lead == _leadTime,
                      onPressed: () => setState(() => _leadTime = lead),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                planned.isEmpty
                    ? l10n.noUpcomingClosures
                    : planned
                          .take(5)
                          .map(
                            (Reminder r) => Fmt.stamp(
                              Localizations.localeOf(context).toLanguageTag(),
                              r.at,
                            ),
                          )
                          .join('\n'),
                style: PixelText.bodySmall.copyWith(
                  color: PixelPalette.inkDim,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
