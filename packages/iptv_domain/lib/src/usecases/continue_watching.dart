import '../common/failure.dart';
import '../entities/continue_row.dart';
import '../entities/episode.dart';
import '../entities/watch_progress.dart';
import '../ports/catalog_repository.dart';
import '../ports/watch_progress_repository.dart';
import 'series_progress.dart';

/// Compose « Continuer à regarder » : une entrée par film ou par série, toutes
/// versions confondues.
///
/// Une série montre son épisode le plus avancé, dans la dernière version
/// regardée. S'il est fini, elle passe à l'épisode suivant ; après le dernier
/// disponible, elle est « à jour » et ne reste que si sa suite est annoncée.
/// Un film fini disparaît.
final class ContinueWatching {
  const ContinueWatching(this._progress, this._catalog);

  final WatchProgressRepository _progress;
  final CatalogRepository _catalog;

  Future<ContinueRow> call(int sourceId, {int limit = 20}) async {
    final history = await _progress.history(sourceId);
    // Dans l'ordre de l'historique : la série regardée en dernier d'abord.
    final groups = <String, List<WatchProgress>>{};
    for (final item in history) {
      (groups[item.groupKey] ??= []).add(item);
    }
    final entries = <WatchProgress>[];
    final caughtUp = <CaughtUpSeries>[];
    for (final group in groups.values) {
      if (entries.length + caughtUp.length >= limit) break;
      if (group.first.seriesKey == null) {
        if (_single(group) case final entry?) entries.add(entry);
        continue;
      }
      final found = await _series(sourceId, group);
      if (found.entry case final entry?) entries.add(entry);
      if (found.caughtUp case final series?) caughtUp.add(series);
    }
    return ContinueRow(entries, caughtUp: caughtUp);
  }

  /// Film, ou reprise sans identité commune : la dernière version regardée,
  /// tant qu'elle n'est pas finie.
  WatchProgress? _single(List<WatchProgress> group) {
    final latest = group.first;
    return latest.finished ? null : latest;
  }

  /// L'entrée d'une série, ou la série à jour : tout ce que la playlist
  /// propose a été vu.
  Future<({WatchProgress? entry, CaughtUpSeries? caughtUp})> _series(
    int sourceId,
    List<WatchProgress> group,
  ) async {
    final latest = group.first;
    final target = group.reduce(
      (best, item) => _order(item) > _order(best) ? item : best,
    );
    // Sans catalogue, la reprise elle-même reste lisible.
    final fallback = (entry: target.finished ? null : target, caughtUp: null);
    try {
      final found = await _catalog.episodeByContentKey(
        sourceId,
        latest.contentKey,
      );
      if (found == null) return fallback;
      // Dans la version regardée en dernier : l'épisode le plus avancé à la
      // position où il en était, quelle que soit sa version, ou le suivant.
      final resume = SeriesProgress(
        group,
      ).resumeIn(await _catalog.seasonsOf(sourceId, found.$2.seriesEntryId));
      if (resume == null) {
        if (!target.finished) return fallback;
        return (
          entry: null,
          caughtUp: CaughtUpSeries(progress: target, series: found.$1),
        );
      }
      if (!target.finished && target.contentKey == latest.contentKey) {
        return (entry: latest, caughtUp: null);
      }
      return (entry: _episodeEntry(latest, resume), caughtUp: null);
    } on Failure {
      return fallback;
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
