import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../l10n/app_localizations.dart';
import '../../domain/models/closure.dart';
import '../status/status_view_model.dart';
import '../theme/palette.dart';
import '../theme/pixel_theme.dart';
import '../widgets/closure_card.dart';
import '../widgets/pixel_panel.dart';

/// Every closure still to come, in order.
class ScheduleView extends StatelessWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    final StatusViewModel vm = context.watch<StatusViewModel>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final tz.TZDateTime now = vm.now as tz.TZDateTime;
    final List<Closure> upcoming = vm.upcoming;

    if (upcoming.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          PixelPanel(
            title: l10n.scheduleTitle,
            child: Text(
              l10n.scheduleEmpty,
              style: PixelText.body.copyWith(color: PixelPalette.inkDim),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: upcoming.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.scheduleTitle,
              style: PixelText.title.copyWith(color: PixelPalette.open),
            ),
          );
        }
        return ClosureCard(closure: upcoming[index - 1], now: now);
      },
    );
  }
}
