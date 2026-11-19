import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/app_state.dart';
import '../../app/di/repository_providers.dart';
import '../../design_system/components/aero_menu.dart';
import '../../l10n/version_names.dart';
import '../player/player_target.dart';
import 'movie_versions.dart';
import 'screens/movie_detail_screen.dart';

/// Ouvre la fiche d'un film. Si plusieurs versions existent, le sélecteur de
/// version s'affiche d'abord, comme pour une série. La fiche propose de
/// reprendre là où le film en était, quelle que soit la version regardée.
Future<void> openMovie(BuildContext context, WidgetRef ref, Movie movie) async {
  final source = ref.read(activeSourceProvider);
  if (source == null) return;
  final navigator = Navigator.of(context);
  final chosen = await _chooseVersion(context, ref, source.id, movie);
  if (chosen == null || !context.mounted) return;
  final history = await ref
      .read(watchProgressRepositoryProvider)
      .progressOf(source.id, WorkKeys.movie(chosen.groupingKey));
  await navigator.push(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => MovieDetailScreen(
        sourceId: source.id,
        movie: chosen,
        resumeAt: movieResumeAt(history),
      ),
    ),
  );
}

/// Lance un film sans passer par sa fiche, comme le bouton « Lire » de
/// l'accueil. Si plusieurs versions existent, le sélecteur s'affiche d'abord.
Future<void> playMovie(BuildContext context, WidgetRef ref, Movie movie) async {
  final source = ref.read(activeSourceProvider);
  if (source == null) return;
  final chosen = await _chooseVersion(context, ref, source.id, movie);
  if (chosen == null || !context.mounted) return;
  await openPlayer(context, PlayerTarget.movie(source.id, chosen));
}

/// La version de [movie] à ouvrir : la seule, ou celle choisie dans le
/// sélecteur. `null` si l'utilisateur renonce.
Future<Movie?> _chooseVersion(
  BuildContext context,
  WidgetRef ref,
  int sourceId,
  Movie movie,
) async {
  final l10n = context.l10n;
  final versions = await movieVersionsOf(ref, sourceId, movie);
  if (!context.mounted) return null;
  if (versions.length <= 1) return versions.single;
  final picked = await showAeroMenu(
    context,
    title: l10n.detailChooseVersion,
    options: movieVersionNames(
      versions,
      l10n,
      ref.read(settingsProvider).languageCode,
    ),
  );
  return picked == null ? null : versions[picked];
}
