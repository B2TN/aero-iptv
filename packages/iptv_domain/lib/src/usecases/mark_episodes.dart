import '../entities/content_kind.dart';
import '../entities/episode.dart';
import '../entities/series.dart';
import '../entities/watch_progress.dart';
import '../ports/watch_progress_repository.dart';
import 'series_progress.dart';

/// Marque des épisodes comme vus ou non vus, toutes versions confondues.
final class MarkEpisodes {
  MarkEpisodes(this._progress, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final WatchProgressRepository _progress;
  final DateTime Function() _clock;

  /// Marque [episodes] de [series] comme vus, d'après ce qui l'est déjà dans
  /// [seen]. Un épisode commencé reste dans la version où il l'a été ; les
  /// autres prennent celle de [episodes].
  Future<void> watched(
    int sourceId,
    Series series,
    Iterable<Episode> episodes,
    SeriesProgress seen,
  ) async {
    final now = _clock();
    for (final episode in episodes) {
      final known = seen.of(episode.season, episode.number);
      if (known != null && known.finished) continue;
      await _progress.save(
        WatchProgress(
          sourceId: sourceId,
          contentKey: known?.contentKey ?? episode.contentKey,
          kind: ContentKind.series,
          title: known?.title ?? series.title,
          // Fini, il compte comme vu jusqu'au bout, durée connue ou non.
          position: known?.duration ?? Duration.zero,
          duration: known?.duration ?? Duration.zero,
          updatedAt: now,
          locator: known?.locator ?? episode.locator,
          posterUrl: known?.posterUrl ?? series.posterUrl,
          workKey: WorkKeys.episode(
            series.groupingKey,
            episode.season,
            episode.number,
          ),
          seriesKey: series.groupingKey,
          season: episode.season,
          episode: episode.number,
          finished: true,
        ),
      );
    }
  }

  /// Oublie ce qui a été vu de [episodes], dans toutes les versions de
  /// [seen] : ils redeviennent jamais commencés.
  Future<void> unwatched(
    int sourceId,
    Iterable<Episode> episodes,
    SeriesProgress seen,
  ) async {
    final places = {
      for (final episode in episodes) (episode.season, episode.number),
    };
    for (final item in seen.history) {
      if (places.contains((item.season, item.episode))) {
        await _progress.remove(sourceId, item.contentKey);
      }
    }
  }
}
