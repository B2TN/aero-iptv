import '../common/failure.dart';
import '../entities/episode.dart';
import '../entities/watch_progress.dart';
import '../ports/catalog_repository.dart';
import '../ports/watch_progress_repository.dart';
import 'next_episode.dart';

/// Compose « Continuer à regarder » : une entrée par film ou par série, toutes
/// versions confondues.
///
/// Une série montre son épisode le plus avancé, dans la dernière version
/// regardée. S'il est fini, elle passe à l'épisode suivant, et disparaît après
/// le dernier disponible. Un film fini disparaît.
final class ContinueWatching {
  const ContinueWatching(this._progress, this._catalog);

  final WatchProgressRepository _progress;
  final CatalogRepository _catalog;

  Future<List<WatchProgress>> call(int sourceId, {int limit = 20}) async {
    final history = await _progress.history(sourceId);
    // Dans l'ordre de l'historique : la série regardée en dernier d'abord.
    final groups = <String, List<WatchProgress>>{};
    for (final item in history) {
      (groups[item.groupKey] ??= []).add(item);
    }
    final entries = <WatchProgress>[];
    for (final group in groups.values) {
      if (entries.length >= limit) break;
      final entry = group.first.seriesKey == null
          ? _single(group)
          : await _series(sourceId, group);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  /// Film, ou reprise sans identité commune : la dernière version regardée,
  /// tant qu'elle n'est pas finie.
  WatchProgress? _single(List<WatchProgress> group) {
    final latest = group.first;
    return latest.finished ? null : latest;
  }

  Future<WatchProgress?> _series(
    int sourceId,
    List<WatchProgress> group,
  ) async {
    final latest = group.first;
    final target = group.reduce(
      (best, item) => _order(item) > _order(best) ? item : best,
    );
    // Les épisodes de la dernière version regardée.
    final List<Episode> episodes;
    try {
      final found = await _catalog.episodeByContentKey(
        sourceId,
        latest.contentKey,
      );
      if (found == null) return target.finished ? null : target;
      final seasons = await _catalog.seasonsOf(
        sourceId,
        found.$2.seriesEntryId,
      );
      episodes = [for (final season in seasons) ...season.episodes];
      if (target.finished) {
        final current = episodes
            .where((episode) => _matches(episode, target))
            .firstOrNull;
        final following = current == null
            ? null
            : nextEpisode(seasons, current);
        return following == null ? null : _episodeEntry(latest, following);
      }
    } on Failure {
      // Sans catalogue, la reprise elle-même reste lisible.
      return target.finished ? null : target;
    }
    if (target.contentKey == latest.contentKey) return latest;
    // L'épisode le plus avancé, dans la version regardée en dernier, à la
    // position où il en était, quelle que soit sa version.
    final same = episodes.where((episode) => _matches(episode, target));
    return same.isEmpty
        ? target
        : _episodeEntry(latest, same.first, from: target);
  }

  /// Rang d'un épisode dans la série : saison, puis numéro.
  static int _order(WatchProgress item) =>
      (item.season ?? 0) * 10000 + (item.episode ?? 0);

  static bool _matches(Episode episode, WatchProgress item) =>
      episode.season == item.season && episode.number == item.episode;

  /// Entrée pour [episode] de la version de [latest], reprise à la position de
  /// [from] s'il en avait une.
  static WatchProgress _episodeEntry(
    WatchProgress latest,
    Episode episode, {
    WatchProgress? from,
  }) => latest.copyWith(
    contentKey: episode.contentKey,
    locator: episode.locator,
    workKey: WorkKeys.episode(
      latest.seriesKey!,
      episode.season,
      episode.number,
    ),
    season: episode.season,
    episode: episode.number,
    position: from?.position ?? Duration.zero,
    duration: from?.duration ?? Duration.zero,
    finished: false,
  );
}
