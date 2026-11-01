import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/app_state.dart';
import '../../app/di/repository_providers.dart';
import '../../design_system/components/aero_menu.dart';
import '../../l10n/version_names.dart';
import '../player/player_target.dart';

/// Ouvre un film. Si plusieurs versions existent, le sélecteur s'affiche d'abord.
Future<void> openMovie(BuildContext context, WidgetRef ref, Movie movie) async {
  final source = ref.read(activeSourceProvider);
  if (source == null) return;
  final l10n = context.l10n;
  final language = ref.read(settingsProvider).languageCode;
  final movies = await ref.read(catalogRepositoryProvider).moviesByTitleKeys(
    source.id,
    {GroupingKey.of(movie.title)},
  );
  if (!context.mounted) return;

  var chosen = movie;
  if (movies.length > 1) {
    final versions = versionsByLanguage(
      movies,
      (version) => version.languageTag ?? version.rawTitle,
      language,
    );
    final picked = await showAeroMenu(
      context,
      title: l10n.detailChooseVersion,
      options: movieVersionNames(versions, l10n, language),
    );
    if (picked == null || !context.mounted) return;
    chosen = versions[picked];
  }
  await openPlayer(context, PlayerTarget.movie(source.id, chosen));
}
