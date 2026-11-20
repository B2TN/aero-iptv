import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart';
import '../remote/apple_charts_client.dart';
import '../remote/tmdb_client.dart';

/// Tendances de TMDB si un jeton est configuré : les titres du moment qu'on
/// peut regarder dans le pays. Sans jeton, les classements Apple du pays.
///
/// Les classements sont gardés dans la base : l'accueil les lit sans réseau.
final class TrendingRepositoryImpl implements TrendingRepository {
  TrendingRepositoryImpl(
    this._db, {
    TmdbClient? tmdb,
    AppleChartsClient? charts,
    DateTime Function()? clock,
  }) : _tmdb = tmdb,
       _charts = charts,
       _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final TmdbClient? _tmdb;
  final AppleChartsClient? _charts;
  final DateTime Function() _clock;

  @override
  bool get isAvailable => _tmdb != null || _charts != null;

  /// Clé d'un pays dans la base, par source : arriver avec un jeton TMDB
  /// fait recharger des classements qui venaient d'Apple.
  String _key(String region) => '$region/${_tmdb != null ? 'tmdb' : 'apple'}';

  @override
  Future<List<TrendingItem>> popular(ContentKind kind, {String? region}) async {
    if (region == null) return const [];
    return [
      for (final row
          in await _db.trendingOf(region: _key(region), kind: kind.index).get())
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
    final stamp = await _db
        .trendingRefreshedAt(region: _key(region))
        .getSingle();
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
      for (final kind in [ContentKind.movie, ContentKind.series])
        kind: await attempt(() => _fetch(kind, region, language)),
    };
    if (fetched.values.every((items) => items == null)) {
      throw failure ?? const NetworkFailure('Aucun service de tendances.');
    }
    final fetchedAt = _clock().millisecondsSinceEpoch;
    final key = _key(region);
    await _db.transaction(() async {
      // Seul le pays en cours sert.
      await (_db.delete(
        _db.trendingTitles,
      )..where((row) => row.region.equals(key).not())).go();
      for (final MapEntry(key: kind, value: items) in fetched.entries) {
        if (items == null) continue;
        await (_db.delete(_db.trendingTitles)..where(
              (row) => row.region.equals(key) & row.kind.equals(kind.index),
            ))
            .go();
        await _db.batch(
          (batch) => batch.insertAll(_db.trendingTitles, [
            for (final (index, item) in items.indexed)
              TrendingTitlesCompanion.insert(
                region: key,
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

  Future<List<TrendingItem>> _fetch(
    ContentKind kind,
    String region,
    String language,
  ) async {
    final tmdb = _tmdb;
    if (tmdb != null) {
      return tmdb.trending(
        kind,
        language: language,
        region: region,
        now: _clock(),
      );
    }
    return await _charts?.popular(kind, region: region) ?? const [];
  }
}
