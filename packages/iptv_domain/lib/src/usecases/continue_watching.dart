import '../common/failure.dart';
import '../entities/episode.dart';
import '../entities/watch_progress.dart';
import '../ports/catalog_repository.dart';
import '../ports/watch_progress_repository.dart';
import 'series_progress.dart';

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
    try {
      final found = await _catalog.episodeByContentKey(
        sourceId,
        latest.contentKey,
      );
      if (found == null) return target.finished ? null : target;
      // Dans la version regardée en dernier : l'épisode le plus avancé à la
      // position où il en était, quelle que soit sa version, ou le suivant.
      final resume = SeriesProgress(
        group,
      ).resumeIn(await _catalog.seasonsOf(sourceId, found.$2.seriesEntryId));
      if (resume == null) return target.finished ? null : target;
      if (!target.finished && target.contentKey == latest.contentKey) {
        return latest;
      }
      return _episodeEntry(latest, resume);
    } on Failure {
      // Sans catalogue, la reprise elle-même reste lisible.
      return target.finished ? null : target;
    }
  }

  /// Rang d'un épisode dans la série : saison, puis numéro.
  static int _order(WatchProgress item) =>
      (item.season ?? 0) * 10000 + (item.episode ?? 0);

  /// Entrée pour [resume], dans la version de son épisode.
  static WatchProgress _episodeEntry(
    WatchProgress latest,
    SeriesResume resume,
  ) {
    final Episode episode = resume.episode;
    return latest.copyWith(
      contentKey: episode.contentKey,
      locator: episode.locator,
      workKey: WorkKeys.episode(
        latest.seriesKey!,
        episode.season,
        episode.number,
      ),
      season: episode.season,
      episode: episode.number,
      position: resume.position,
      duration: resume.duration,
      finished: false,
    );
  }
}
