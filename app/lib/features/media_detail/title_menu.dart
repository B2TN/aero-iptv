import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/app_state.dart';
import '../../app/di/repository_providers.dart';
import '../../design_system/components/aero_menu.dart';
import '../../l10n/version_names.dart';
import '../favorites/favorites_state.dart';
import '../player/player_target.dart';
import 'movie_versions.dart';
import 'open_continued.dart';
import 'open_movie.dart';
import 'open_series.dart';
import 'screens/movie_detail_screen.dart';
import 'widgets/episode_lines.dart';

/// Reprises gardées au plus : de quoi couvrir largement celles de l'accueil.
const int _progressScanned = 200;

typedef _MenuAction = ({String label, Future<void> Function() run});

/// Menu d'un film : appui long sur OK, touche Menu, ou clic droit.
Future<void> showMovieMenu(
  BuildContext context,
  WidgetRef ref,
  Movie movie,
) async {
  final source = ref.read(activeSourceProvider);
  if (source == null) return;
  final l10n = context.l10n;
  final key = movieFavoriteKey(movie);
  final versions = await movieVersionsOf(ref, source.id, movie);
  final played = {movie.contentKey, for (final v in versions) v.contentKey};
  final progress = await _latestProgress(
    ref,
    source.id,
    (item) => played.contains(item.contentKey),
  );
  final favorite = await isFavorite(ref, ContentKind.movie, key);
  if (!context.mounted) return;
  await _run(context, movie.title, [
    (label: l10n.menuOpenPage, run: () => openMovie(context, ref, movie)),
    if (progress != null)
      (
        label: l10n.detailResume,
        run: () => openPlayer(context, PlayerTarget.resume(progress)),
      )
    else
      (
        label: l10n.homePlay,
        run: () => openPlayer(
          context,
          PlayerTarget.movie(
            source.id,
            versions.isEmpty ? movie : versions.first,
          ),
        ),
      ),
    if (versions.length > 1)
      (
        label: l10n.menuChooseVersion,
        run: () => _playMovieVersion(context, ref, source.id, versions),
      ),
    (
      label: favorite ? l10n.menuRemoveFavorite : l10n.menuAddFavorite,
      run: () => toggleFavorite(
        ref,
        kind: ContentKind.movie,
        key: key,
        title: movie.title,
        posterUrl: movie.posterUrl,
      ),
    ),
  ]);
}

/// Menu d'une série : appui long sur OK, touche Menu, ou clic droit.
Future<void> showSeriesMenu(
  BuildContext context,
  WidgetRef ref,
  Series series,
) async {
  final source = ref.read(activeSourceProvider);
  if (source == null) return;
  final l10n = context.l10n;
  final settings = ref.read(settingsProvider);
  final catalog = ref.read(catalogRepositoryProvider);
  final versions = settings.groupSeries
      ? versionsByLanguage(
          await catalog.versionsOf(source.id, series.groupingKey),
          (version) => version.label,
          settings.languageCode,
        )
      : const <MediaVersion>[];
  final progress = await _seriesProgress(ref, source.id, series);
  final favorite = await isFavorite(
    ref,
    ContentKind.series,
    series.groupingKey,
  );
  if (!context.mounted) return;
  await _run(context, series.title, [
    (label: l10n.menuOpenPage, run: () => openSeries(context, ref, series)),
    if (progress != null)
      (
        label: l10n.detailResume,
        run: () => openPlayer(context, PlayerTarget.resume(progress)),
      )
    else
      (
        label: l10n.homePlay,
        run: () => _playFirstEpisode(
          context,
          ref,
          source.id,
          series,
          versions.isEmpty ? series.id : versions.first.seriesEntryId,
        ),
      ),
    if (versions.length > 1)
      (
        label: l10n.menuChooseVersion,
        run: () async {
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
          if (picked == null || !context.mounted) return;
          await openSeriesVersion(
            context,
            source.id,
            series,
            versions[picked].seriesEntryId,
          );
        },
      ),
    (
      label: favorite ? l10n.menuRemoveFavorite : l10n.menuAddFavorite,
      run: () => toggleFavorite(
        ref,
        kind: ContentKind.series,
        key: series.groupingKey,
        title: series.title,
        posterUrl: series.posterUrl,
      ),
    ),
  ]);
}

/// Menu d'un élément de « Continuer à regarder ». [onRemoved] suit son retrait.
Future<void> showContinueMenu(
  BuildContext context,
  WidgetRef ref,
  WatchProgress item, {
  required VoidCallback onRemoved,
}) async {
  final l10n = context.l10n;
  final catalog = ref.read(catalogRepositoryProvider);
  // Le favori porte sur le film ou la série, retrouvés dans le catalogue.
  final ({ContentKind kind, String key, String title, String? poster})? owner =
      switch (item.kind) {
        ContentKind.movie => switch (await catalog.movieByContentKey(
          item.sourceId,
          item.contentKey,
        )) {
          final Movie movie => (
            kind: ContentKind.movie,
            key: movieFavoriteKey(movie),
            title: movie.title,
            poster: movie.posterUrl,
          ),
          null => null,
        },
        ContentKind.series => switch (await catalog.episodeByContentKey(
          item.sourceId,
          item.contentKey,
        )) {
          (final Series series, _) => (
            kind: ContentKind.series,
            key: series.groupingKey,
            title: series.title,
            poster: series.posterUrl,
          ),
          null => null,
        },
        ContentKind.live => null,
      };
  final favorite =
      owner != null && await isFavorite(ref, owner.kind, owner.key);
  if (!context.mounted) return;
  final target = PlayerTarget.resume(item);
  await _run(context, item.title, [
    (label: l10n.homeResume, run: () => openPlayer(context, target)),
    (
      label: l10n.homeRestart,
      run: () => openPlayer(context, target.resumingAt(Duration.zero)),
    ),
    (label: l10n.menuOpenPage, run: () => openContinued(context, ref, item)),
    if (owner != null)
      (
        label: favorite ? l10n.menuRemoveFavorite : l10n.menuAddFavorite,
        run: () => toggleFavorite(
          ref,
          kind: owner.kind,
          key: owner.key,
          title: owner.title,
          posterUrl: owner.poster,
        ),
      ),
    (
      label: l10n.homeRemoveContinue,
      run: () async {
        // Toute la série, ou toutes les versions du film : l'entrée ne doit
        // pas revenir sous un autre épisode ou une autre langue.
        await ref
            .read(watchProgressRepositoryProvider)
            .hide(item.sourceId, item.groupKey);
        onRemoved();
      },
    ),
  ]);
}

/// Menu d'un épisode de la fiche d'une série : appui long sur OK, touche
/// Menu, ou clic droit. [seasons] sont celles de la version montrée,
/// [versions] celles de la série, vides sans regroupement.
Future<void> showEpisodeMenu(
  BuildContext context,
  WidgetRef ref, {
  required int sourceId,
  required Series series,
  required List<Season> seasons,
  required Episode episode,
  required SeriesProgress seen,
  required List<MediaVersion> versions,
}) async {
  final l10n = context.l10n;
  final watched = seen.of(episode.season, episode.number);
  bool done(Episode other) =>
      seen.of(other.season, other.number)?.finished ?? false;
  int place(Episode other) => other.season * 10000 + other.number;
  // Toute la série jusqu'à cet épisode, saisons précédentes comprises.
  final upToHere = [
    for (final season in seasons)
      for (final other in season.episodes)
        if (place(other) <= place(episode)) other,
  ];
  final season = [
    for (final season in seasons)
      if (season.number == episode.season) ...season.episodes,
  ];
  final target = PlayerTarget.episode(sourceId, series, episode);
  final mark = ref.read(markEpisodesProvider);
  // Les fiches et l'accueil relisent ce qui a été vu.
  Future<void> marked(Future<void> change) async {
    await change;
    ref.read(watchedRevisionProvider.notifier).bump();
  }

  await _run(context, episodeLabel(l10n, series, episode), [
    if (watched != null && watched.inProgress) ...[
      (
        label: l10n.detailResume,
        run: () => openPlayer(context, target.resumingAt(watched.position)),
      ),
      (
        label: l10n.detailPlayFromStart,
        run: () => openPlayer(context, target.resumingAt(Duration.zero)),
      ),
    ] else
      (label: l10n.homePlay, run: () => openPlayer(context, target)),
    if (!done(episode))
      (
        label: l10n.menuMarkWatched,
        run: () => marked(mark.watched(sourceId, series, [episode], seen)),
      ),
    if (watched != null)
      (
        label: l10n.menuMarkUnwatched,
        run: () => marked(mark.unwatched(sourceId, [episode], seen)),
      ),
    if (upToHere.length > 1 && !upToHere.every(done))
      (
        label: l10n.menuMarkWatchedUpTo,
        run: () => marked(mark.watched(sourceId, series, upToHere, seen)),
      ),
    if (season.every(done))
      (
        label: l10n.menuMarkSeasonUnwatched,
        run: () => marked(mark.unwatched(sourceId, season, seen)),
      )
    else
      (
        label: l10n.menuMarkSeasonWatched,
        run: () => marked(mark.watched(sourceId, series, season, seen)),
      ),
    if (versions.length > 1)
      (
        label: l10n.menuChooseVersion,
        run: () => _playEpisodeVersion(
          context,
          ref,
          sourceId,
          series,
          episode,
          seen,
          versions,
        ),
      ),
  ]);
}

/// Lit [episode] dans une autre version, où il en était dans n'importe
/// laquelle.
Future<void> _playEpisodeVersion(
  BuildContext context,
  WidgetRef ref,
  int sourceId,
  Series series,
  Episode episode,
  SeriesProgress seen,
  List<MediaVersion> versions,
) async {
  final l10n = context.l10n;
  final language = ref.read(settingsProvider).languageCode;
  final picked = await showAeroMenu(
    context,
    title: l10n.detailChooseVersion,
    options: [
      for (final version in versions)
        versionName(version.label, l10n, language, variant: version.variant),
    ],
  );
  if (picked == null || !context.mounted) return;
  Episode? same;
  String? problem;
  try {
    same = [
      for (final season
          in await ref
              .read(catalogRepositoryProvider)
              .seasonsOf(sourceId, versions[picked].seriesEntryId))
        if (season.number == episode.season) ...season.episodes,
    ].where((other) => other.number == episode.number).firstOrNull;
    if (same == null) problem = l10n.playerVersionMissing;
  } on Failure {
    problem = l10n.loadErrorTitle;
  }
  if (!context.mounted) return;
  if (same == null) {
    await showAeroMenu(
      context,
      title: problem ?? l10n.playerVersionMissing,
      options: [l10n.actionBack],
    );
    return;
  }
  await openPlayer(context, episodeTarget(sourceId, series, same, seen));
}

Future<void> _run(
  BuildContext context,
  String title,
  List<_MenuAction> actions,
) async {
  final picked = await showAeroMenu(
    context,
    title: title,
    options: [for (final action in actions) action.label],
  );
  if (picked == null || !context.mounted) return;
  await actions[picked].run();
}

/// Reprise la plus récente qui satisfait [matches], ou `null`.
Future<WatchProgress?> _latestProgress(
  WidgetRef ref,
  int sourceId,
  bool Function(WatchProgress item) matches,
) async {
  final recent = await ref
      .read(watchProgressRepositoryProvider)
      .continueWatching(sourceId, limit: _progressScanned);
  return recent.where(matches).firstOrNull;
}

/// Reprise la plus récente d'un épisode de [series], toutes versions comprises.
Future<WatchProgress?> _seriesProgress(
  WidgetRef ref,
  int sourceId,
  Series series,
) async {
  final catalog = ref.read(catalogRepositoryProvider);
  final recent = await ref
      .read(watchProgressRepositoryProvider)
      .continueWatching(sourceId, limit: _progressScanned);
  for (final item in recent) {
    if (item.kind != ContentKind.series) continue;
    final found = await catalog.episodeByContentKey(sourceId, item.contentKey);
    if (found?.$1.groupingKey == series.groupingKey) return item;
  }
  return null;
}

/// Lit une version d'un film, en reprenant où le film en était, quelle que
/// soit la version regardée.
Future<void> _playMovieVersion(
  BuildContext context,
  WidgetRef ref,
  int sourceId,
  List<Movie> versions,
) async {
  final l10n = context.l10n;
  final picked = await showAeroMenu(
    context,
    title: l10n.detailChooseVersion,
    options: movieVersionNames(
      versions,
      l10n,
      ref.read(settingsProvider).languageCode,
    ),
  );
  if (picked == null || !context.mounted) return;
  final chosen = versions[picked];
  final resumeAt = movieResumeAt(
    await ref
        .read(watchProgressRepositoryProvider)
        .progressOf(sourceId, WorkKeys.movie(chosen.groupingKey)),
  );
  if (!context.mounted) return;
  final target = PlayerTarget.movie(sourceId, chosen);
  await openPlayer(
    context,
    resumeAt == null ? target : target.resumingAt(resumeAt),
  );
}

/// Lance le premier épisode d'une version, ou ouvre sa fiche s'il n'y en a pas.
Future<void> _playFirstEpisode(
  BuildContext context,
  WidgetRef ref,
  int sourceId,
  Series series,
  int entryId,
) async {
  final seasons = await ref
      .read(catalogRepositoryProvider)
      .seasonsOf(sourceId, entryId);
  if (!context.mounted) return;
  final first = seasons.expand((season) => season.episodes).firstOrNull;
  if (first == null) {
    await openSeriesVersion(context, sourceId, series, entryId);
    return;
  }
  await openPlayer(context, PlayerTarget.episode(sourceId, series, first));
}
