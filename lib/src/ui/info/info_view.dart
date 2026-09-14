import '../../core/app_version.dart';

import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/config.dart';
import '../theme/palette.dart';
import '../theme/pixel_theme.dart';
import '../widgets/pixel_button.dart';
import '../widgets/pixel_panel.dart';

/// What the app is, what the data is, and what it is not.
class InfoView extends StatefulWidget {
  const InfoView({super.key});

  @override
  State<InfoView> createState() => _InfoViewState();
}

class _InfoViewState extends State<InfoView> {
  AppVersion? _version;

  @override
  void initState() {
    super.initState();
    AppVersion.load().then((AppVersion? v) {
      if (mounted) setState(() => _version = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Text(
          l10n.infoTitle,
          style: PixelText.title.copyWith(color: PixelPalette.open),
        ),
        const SizedBox(height: 12),

        PixelPanel(
          title: l10n.bridgeName,
          child: Text(l10n.infoWhat, style: PixelText.body),
        ),
        const SizedBox(height: 12),

        // The single most important caveat: these are forecasts.
        PixelPanel(
          borderColor: PixelPalette.warning,
          child: Text(
            l10n.infoForecastCaveat,
            style: PixelText.body.copyWith(color: PixelPalette.warning),
          ),
        ),
        const SizedBox(height: 12),

        PixelPanel(
          child: Text(
            l10n.infoTimesInParis,
            style: PixelText.bodySmall.copyWith(color: PixelPalette.inkDim),
          ),
        ),
        const SizedBox(height: 12),

        PixelPanel(
          title: l10n.infoDataSource,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(ApiConfig.attribution, style: PixelText.body),
              const SizedBox(height: 6),
              Text(
                '${l10n.infoLicence}: ${ApiConfig.licence}',
                style: PixelText.bodySmall.copyWith(color: PixelPalette.inkDim),
              ),
              const SizedBox(height: 14),
              PixelButton(
                label: l10n.infoOpenSourcePage,
                onPressed: () => launchUrl(
                  Uri.parse(ApiConfig.sourcePageUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),
        // Last, and quiet: it exists so a build on a device can be identified,
        // not because anyone came here to read it.
        if (_version != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            '${l10n.infoVersion} ${_version!.label}',
            style: PixelText.bodySmall.copyWith(color: PixelPalette.inkFaint),
          ),
        ],
      ],
    );
  }
}
