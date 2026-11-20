import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/di/repository_providers.dart';
import '../player/player_target.dart';
import 'screens/media_detail_screen.dart';
import 'screens/movie_detail_screen.dart';

/// Ouvre la fiche d'un élément de « Continuer à regarder ». La lecture se
/// reprend depuis la fiche.
///
/// Un contenu absent du catalogue actuel, par exemple retiré par le
/// fournisseur, n'a plus de fiche : la lecture reprend alors directement.
Future<void> openContinued(
  BuildContext context,
  WidgetRef ref,
  WatchProgress item,
) async {
  final navigator = Navigator.of(context);
  final catalog = ref.read(catalogRepositoryProvider);
  final Widget? page = switch (item.kind) {
    ContentKind.movie =>
      await catalog
          .movieByContentKey(item.sourceId, item.contentKey)
          .then(
            (movie) => movie == null
                ? null
                : MovieDetailScreen(
                    sourceId: item.sourceId,
                    movie: movie,
                    resumeAt: item.position,
                  ),
          ),
    ContentKind.series => await _findEpisode(catalog, item).then(
      (found) => found == null
          ? null
          : MediaDetailScreen(
              sourceId: item.sourceId,
              series: found.$1,
              seriesEntryId: found.$2.seriesEntryId,
              // Vu jusqu'au bout : rien à reprendre, la saison suffit.
              resume: item.finished
                  ? null
                  : (episode: found.$2, position: item.position),
              season: found.$2.season,
            ),
    ),
    ContentKind.live => null,
  };
  if (!context.mounted) return;
  if (page == null) {
    await navigator.push(playerRoute(PlayerTarget.resume(item)));
    return;
  }
  await navigator.push(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => page,
    ),
  );
}

/// L'épisode d'une reprise dans le catalogue affiché.
///
/// Les épisodes d'une série Xtream ne sont connus qu'une fois la série
/// ouverte, et un catalogue réimporté a pu les oublier. La série est alors
/// redemandée, version après version, jusqu'à retrouver l'épisode ; à défaut,
/// celui de même saison et de même numéro dans une autre version.
Future<(Series, Episode)?> _findEpisode(
  CatalogRepository catalog,
  WatchProgress item,
) async {
  final known = await catalog.episodeByContentKey(
    item.sourceId,
    item.contentKey,
  );
  final seriesKey = item.seriesKey;
  if (known != null || seriesKey == null) return known;
  Episode? sameNumber;
  for (final version in await catalog.versionsOf(item.sourceId, seriesKey)) {
    final List<Season> seasons;
    try {
      seasons = await catalog.seasonsOf(item.sourceId, version.seriesEntryId);
    } on Failure {
      continue;
    }
    final found = await catalog.episodeByContentKey(
      item.sourceId,
      item.contentKey,
    );
    if (found != null) return found;
    sameNumber ??= seasons
        .expand((season) => season.episodes)
        .where(
          (episode) =>
              episode.season == item.season && episode.number == item.episode,
        )
        .firstOrNull;
  }
  final other = sameNumber;
  return other == null
      ? null
      : catalog.episodeByContentKey(item.sourceId, other.contentKey);
}
