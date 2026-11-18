import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart' hide WatchProgress;
import '../database/locator_columns.dart';

/// Positions de lecture.
final class WatchProgressRepositoryImpl implements WatchProgressRepository {
  const WatchProgressRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<void> save(WatchProgress progress) {
    final locator = LocatorColumns.from(progress.locator);
    return _db
        .into(_db.watchProgress)
        .insertOnConflictUpdate(
          WatchProgressCompanion.insert(
            sourceId: progress.sourceId,
            contentKey: progress.contentKey,
            kind: progress.kind.index,
            title: progress.title,
            posterUrl: Value(progress.posterUrl),
            positionMs: progress.position.inMilliseconds,
            durationMs: progress.duration.inMilliseconds,
            updatedAt: progress.updatedAt.millisecondsSinceEpoch,
            streamUrl: Value(locator.streamUrl),
            xtreamStreamId: Value(locator.xtreamStreamId),
            containerExt: Value(locator.containerExt),
            userAgent: Value(locator.userAgent),
            referrer: Value(locator.referrer),
            workKey: Value(progress.workKey),
            seriesKey: Value(progress.seriesKey),
            season: Value(progress.season),
            episode: Value(progress.episode),
            finished: Value(progress.finished),
            // Relire un contenu retiré le remet dans « Continuer à regarder ».
            hidden: const Value(false),
          ),
        );
  }

  @override
  Future<List<WatchProgress>> continueWatching(
    int sourceId, {
    int limit = 20,
  }) async => [
    for (final row
        in await _db.recentProgress(sourceId: sourceId, limit: limit).get())
      _toProgress(row),
  ];

  @override
  Future<List<WatchProgress>> history(
    int sourceId, {
    int limit = 500,
  }) async => [
    for (final row
        in await _db.progressHistory(sourceId: sourceId, limit: limit).get())
      _toProgress(row),
  ];

  @override
  Future<void> hide(int sourceId, String groupKey) =>
      _db.hideProgress(sourceId: sourceId, groupKey: groupKey);

  WatchProgress _toProgress(WatchProgressRow row) => WatchProgress(
    sourceId: row.sourceId,
    contentKey: row.contentKey,
    kind: ContentKind.values[row.kind],
    title: row.title,
    posterUrl: row.posterUrl,
    position: Duration(milliseconds: row.positionMs),
    duration: Duration(milliseconds: row.durationMs),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    locator:
        LocatorColumns(
          streamUrl: row.streamUrl,
          xtreamStreamId: row.xtreamStreamId,
          containerExt: row.containerExt,
          userAgent: row.userAgent,
          referrer: row.referrer,
        ).toLocator(
          row.kind == ContentKind.series.index
              ? XtreamNamespace.series
              : XtreamNamespace.movie,
        ),
    workKey: row.workKey,
    seriesKey: row.seriesKey,
    season: row.season,
    episode: row.episode,
    finished: row.finished,
  );

  @override
  Future<void> remove(int sourceId, String contentKey) =>
      _db.deleteProgress(sourceId: sourceId, contentKey: contentKey);
}
