import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/app_state.dart';
import '../../app/di/repository_providers.dart';
import '../../design_system/components/aero_menu.dart';
import '../../l10n/version_names.dart';
import 'screens/media_detail_screen.dart';

/// Ouvre une série. Si plusieurs versions existent, le sélecteur de version
/// s'affiche d'abord.
Future<void> openSeries(
  BuildContext context,
  WidgetRef ref,
  Series series,
) async {
  final source = ref.read(activeSourceProvider);
  if (source == null) return;
  final settings = ref.read(settingsProvider);
  final grouped = settings.groupSeries;
  final l10n = context.l10n;
  final navigator = Navigator.of(context);

  var entryId = series.id;
  if (grouped) {
    final all = await ref
        .read(catalogRepositoryProvider)
        .versionsOf(source.id, series.groupingKey);
    if (all.isEmpty || !context.mounted) return;
    final versions = versionsByLanguage(
      all,
      (version) => version.label,
      settings.languageCode,
    );
    var choice = 0;
    if (versions.length > 1) {
      final picked = await showAeroMenu(
        context,
        title: l10n.detailChooseVersion,
        options: [
          for (final version in versions)
            versionName(
              version.label,
              l10n,
              settings.languageCode,
              variant: version.variant,
            ),
        ],
      );
      if (picked == null) return;
      choice = picked;
    }
    entryId = versions[choice].seriesEntryId;
  }
  await navigator.push(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => MediaDetailScreen(
        sourceId: source.id,
        series: series,
        seriesEntryId: entryId,
      ),
    ),
  );
}
