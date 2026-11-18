import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/app_state.dart';
import '../../app/di/repository_providers.dart';
import '../../l10n/version_names.dart';
import 'screens/player_screen.dart';

/// Autre version du contenu en cours de lecture.
final class PlayerVersion {
  const PlayerVersion({required this.label, required this.open});

  final String label;

  /// Prépare la lecture. Retourne `null` si cette version ne contient pas le
  /// contenu, par exemple un épisode absent.
  final Future<PlayerTarget?> Function() open;
}

/// Charge les versions, seulement si l'utilisateur les demande.
typedef PlayerVersionLoader =
    Future<List<PlayerVersion>> Function(WidgetRef ref, BuildContext context);

/// Cherche ce qui suit le contenu en cours, `null` s'il n'y a rien.
typedef PlayerNextLoader = Future<PlayerTarget?> Function(WidgetRef ref);

/// Les saisons de la version en cours de lecture, et l'épisode lu.
typedef PlayerEpisodes = ({
  Series series,
  List<Season> seasons,
  Episode current,
});

/// Charge les épisodes de la série, seulement si l'utilisateur les demande ;
/// `null` si le catalogue ne connaît plus l'épisode.
typedef PlayerEpisodesLoader = Future<PlayerEpisodes?> Function(WidgetRef ref);

/// Lecture de [episode] : commencé dans n'importe quelle version, il reprend
/// où il en était ; fini ou jamais commencé, il part du début.
PlayerTarget episodeTarget(
  int sourceId,
  Series series,
  Episode episode,
  SeriesProgress seen,
) {
  final target = PlayerTarget.episode(sourceId, series, episode);
  final watched = seen.of(episode.season, episode.number);
  return watched != null && watched.inProgress
      ? target.resumingAt(watched.position)
      : target;
}

/// Contenu à ouvrir dans le lecteur.
final class PlayerTarget {
  const PlayerTarget({
    required this.item,
    this.resumeAt,
    this.versions,
    this.next,
    this.episodes,
  });

  factory PlayerTarget.movie(int sourceId, Movie movie) => PlayerTarget(
    versions: (ref, context) async {
      final l10n = context.l10n;
      final language = ref.read(settingsProvider).languageCode;
      final movies = await ref
          .read(catalogRepositoryProvider)
          .moviesByTitleKeys(sourceId, {GroupingKey.of(movie.title)});
      final names = movieVersionNames(movies, l10n, language);
      return [
        for (final (index, version) in movies.indexed)
          PlayerVersion(
            label: names[index],
            open: () async => PlayerTarget.movie(sourceId, version),
          ),
      ];
    },
    item: PlaybackItem(
      sourceId: sourceId,
      contentKey: movie.contentKey,
      title: movie.title,
      kind: ContentKind.movie,
      locator: movie.locator,
      posterUrl: movie.posterUrl,
      year: movie.year,
      workKey: WorkKeys.movie(movie.title),
    ),
  );

  factory PlayerTarget.episode(int sourceId, Series series, Episode episode) =>
      PlayerTarget(
        next: (ref) async {
          final seasons = await ref
              .read(catalogRepositoryProvider)
              .seasonsOf(sourceId, episode.seriesEntryId);
          final following = nextEpisode(seasons, episode);
          return following == null
              ? null
              : PlayerTarget.episode(sourceId, series, following);
        },
        episodes: (ref) async => (
          series: series,
          seasons: await ref
              .read(catalogRepositoryProvider)
              .seasonsOf(sourceId, episode.seriesEntryId),
          current: episode,
        ),
        versions: (ref, context) async {
          final l10n = context.l10n;
          final language = ref.read(settingsProvider).languageCode;
          final catalog = ref.read(catalogRepositoryProvider);
          final versions = await catalog.versionsOf(
            sourceId,
            series.groupingKey,
          );
          return [
            for (final version in versions)
              PlayerVersion(
                label: versionName(
                  version.label,
                  l10n,
                  language,
                  variant: version.variant,
                ),
                open: () async {
                  final seasons = await catalog.seasonsOf(
                    sourceId,
                    version.seriesEntryId,
                  );
                  final same = seasons
                      .where((season) => season.number == episode.season)
                      .expand((season) => season.episodes)
                      .where((other) => other.number == episode.number)
                      .firstOrNull;
                  return same == null
                      ? null
                      : PlayerTarget.episode(sourceId, series, same);
                },
              ),
          ];
        },
        item: PlaybackItem(
          sourceId: sourceId,
          contentKey: episode.contentKey,
          title: series.title,
          kind: ContentKind.series,
          locator: episode.locator,
          posterUrl: series.posterUrl,
          year: series.year,
          season: episode.season,
          episode: episode.number,
          workKey: WorkKeys.episode(
            series.groupingKey,
            episode.season,
            episode.number,
          ),
          seriesKey: series.groupingKey,
        ),
      );

  /// [streams] liste les autres flux de la chaîne, proposés comme versions.
  factory PlayerTarget.channel(
    int sourceId,
    Channel channel,
    ChannelStream stream, {
    List<ChannelStream> streams = const [],
  }) => PlayerTarget(
    versions: (ref, context) async => [
      for (final other in streams)
        PlayerVersion(
          label: other.label.isEmpty ? other.quality.label : other.label,
          open: () async =>
              PlayerTarget.channel(sourceId, channel, other, streams: streams),
        ),
    ],
    item: PlaybackItem(
      sourceId: sourceId,
      contentKey: 'live:${channel.groupingKey}',
      title: channel.name,
      kind: ContentKind.live,
      locator: stream.locator,
    ),
  );

  factory PlayerTarget.resume(WatchProgress progress) => PlayerTarget(
    resumeAt: progress.position,
    next: (ref) async {
      if (progress.kind != ContentKind.series) return null;
      final found = await ref
          .read(catalogRepositoryProvider)
          .episodeByContentKey(progress.sourceId, progress.contentKey);
      if (found == null) return null;
      final (series, episode) = found;
      final current = PlayerTarget.episode(progress.sourceId, series, episode);
      return current.next?.call(ref);
    },
    episodes: progress.kind != ContentKind.series
        ? null
        : (ref) async {
            final found = await ref
                .read(catalogRepositoryProvider)
                .episodeByContentKey(progress.sourceId, progress.contentKey);
            if (found == null) return null;
            final (series, episode) = found;
            return PlayerTarget.episode(
              progress.sourceId,
              series,
              episode,
            ).episodes?.call(ref);
          },
    versions: (ref, context) async {
      final catalog = ref.read(catalogRepositoryProvider);
      final sourceId = progress.sourceId;
      final key = progress.contentKey;
      final PlayerTarget? current;
      if (progress.kind == ContentKind.movie) {
        final movie = await catalog.movieByContentKey(sourceId, key);
        current = movie == null ? null : PlayerTarget.movie(sourceId, movie);
      } else {
        final found = await catalog.episodeByContentKey(sourceId, key);
        current = found == null
            ? null
            : PlayerTarget.episode(sourceId, found.$1, found.$2);
      }
      if (!context.mounted) return const [];
      return await current?.versions?.call(ref, context) ?? const [];
    },
    item: PlaybackItem(
      sourceId: progress.sourceId,
      contentKey: progress.contentKey,
      title: progress.title,
      kind: progress.kind,
      locator: progress.locator,
      posterUrl: progress.posterUrl,
      season: progress.season,
      episode: progress.episode,
      workKey: progress.workKey,
      seriesKey: progress.seriesKey,
    ),
  );

  final PlaybackItem item;
  final Duration? resumeAt;

  /// `null` si les versions sont inconnues, comme pour une reprise de lecture.
  final PlayerVersionLoader? versions;

  /// `null` pour un contenu sans suite, comme un film.
  final PlayerNextLoader? next;

  /// `null` hors d'une série : le lecteur n'a alors pas de bouton Épisodes.
  final PlayerEpisodesLoader? episodes;

  bool get isLive => item.kind == ContentKind.live;

  /// Même contenu, repris à [position].
  PlayerTarget resumingAt(Duration position) => PlayerTarget(
    item: item,
    resumeAt: position,
    versions: versions,
    next: next,
    episodes: episodes,
  );
}

Route<void> playerRoute(PlayerTarget target) => PageRouteBuilder<void>(
  transitionDuration: Duration.zero,
  reverseTransitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => PlayerScreen(target: target),
);

Future<void> openPlayer(BuildContext context, PlayerTarget target) =>
    Navigator.of(context).push(playerRoute(target));
