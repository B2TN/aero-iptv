import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart';
import '../remote/apple_charts_client.dart';
import '../remote/segment_clients.dart';
import '../remote/tmdb_client.dart';

/// Tendances TMDb si un jeton est configuré. Sinon, les séries diffusées cette
/// semaine selon TVmaze, complétées par le classement Apple du pays, et les
/// films du classement Apple.
///
/// Les classements sont gardés dans la base : l'accueil les lit sans réseau.
final class TrendingRepositoryImpl implements TrendingRepository {
  TrendingRepositoryImpl(
    this._db, {
    TmdbClient? tmdb,
    AppleChartsClient? charts,
    TvMazeClient? tvMaze,
    DateTime Function()? clock,
  }) : _tmdb = tmdb,
       _charts = charts,
       _tvMaze = tvMaze,
       _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final TmdbClient? _tmdb;
  final AppleChartsClient? _charts;
  final TvMazeClient? _tvMaze;
  final DateTime Function() _clock;

  @override
  bool get isAvailable => _tmdb != null || _charts != null || _tvMaze != null;

  @override
  Future<List<TrendingItem>> popular(ContentKind kind, {String? region}) async {
    if (region == null) return const [];
    return [
      for (final row
          in await _db.trendingOf(region: region, kind: kind.index).get())
        TrendingItem(
          kind: kind,
          title: row.title,
          originalTitle: row.originalTitle,
          overview: row.overview,
          posterUrl: row.posterUrl,
          backdropUrl: row.backdropUrl,
        ),
    ];
  }

  @override
  Future<DateTime?> refreshedAt(String region) async {
    final stamp = await _db.trendingRefreshedAt(region: region).getSingle();
    return stamp == null ? null : DateTime.fromMillisecondsSinceEpoch(stamp);
  }

  @override
  Future<void> refresh(String region, {required String language}) async {
    Failure? failure;
    Future<List<TrendingItem>?> attempt(
      Future<List<TrendingItem>> Function() fetch,
    ) async {
      try {
        return await fetch();
      } on Failure catch (error) {
        failure = error;
        return null;
      }
    }

    // Un service muet garde ses classements précédents.
    final fetched = {
      ContentKind.movie: await attempt(() => _movies(region, language)),
      ContentKind.series: await attempt(() => _series(region, language)),
    };
    if (fetched.values.every((items) => items == null)) {
      throw failure ?? const NetworkFailure('Aucun service de tendances.');
    }
    final fetchedAt = _clock().millisecondsSinceEpoch;
    await _db.transaction(() async {
      // Seul le pays en cours sert.
      await (_db.delete(
        _db.trendingTitles,
      )..where((row) => row.region.equals(region).not())).go();
      for (final MapEntry(key: kind, value: items) in fetched.entries) {
        if (items == null) continue;
        await (_db.delete(_db.trendingTitles)..where(
              (row) => row.region.equals(region) & row.kind.equals(kind.index),
            ))
            .go();
        await _db.batch(
          (batch) => batch.insertAll(_db.trendingTitles, [
            for (final (index, item) in items.indexed)
              TrendingTitlesCompanion.insert(
                region: region,
                kind: kind.index,
                sortOrder: index,
                title: item.title,
                originalTitle: item.originalTitle,
                overview: Value(item.overview),
                posterUrl: Value(item.posterUrl),
                backdropUrl: Value(item.backdropUrl),
                fetchedAt: fetchedAt,
              ),
          ]),
        );
      }
    });
  }

  Future<List<TrendingItem>> _movies(String region, String language) async {
    final tmdb = _tmdb;
    if (tmdb != null) {
      return tmdb.popular(
        ContentKind.movie,
        language: language,
        region: region,
      );
    }
    return await _charts?.popular(ContentKind.movie, region: region) ??
        const [];
  }

  /// TVmaze connaît les séries du moment, mais presque pas les chaînes de
  /// certains pays, comme la France : le classement Apple du pays complète.
  Future<List<TrendingItem>> _series(String region, String language) async {
    final tmdb = _tmdb;
    if (tmdb != null) {
      return tmdb.popular(
        ContentKind.series,
        language: language,
        region: region,
      );
    }
    final sources = <Future<List<TrendingItem>> Function()>[
      if (_tvMaze case final tvMaze?)
        () => tvMaze.airingThisWeek(region, now: _clock()),
      if (_charts case final charts?)
        () => charts.popular(ContentKind.series, region: region),
    ];
    Failure? failure;
    final lists = <List<TrendingItem>>[];
    for (final fetch in sources) {
      try {
        lists.add(await fetch());
      } on Failure catch (error) {
        failure = error;
      }
    }
    if (lists.isEmpty && failure != null) throw failure;
    final seen = <String>{};
    return [
      for (final item in lists.expand((list) => list))
        if (seen.add(GroupingKey.of(item.title))) item,
    ];
  }
}
