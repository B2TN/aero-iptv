import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/xtream/xtream_api_client.dart';
import '../database/app_database.dart';
import '../database/locator_columns.dart';

/// Lecture des films et des séries.
final class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl(this._db, this._credentials, this._client);

  final AppDatabase _db;
  final CredentialStore _credentials;
  final http.Client _client;

  @override
  Future<Page<Movie>> movies(int sourceId, PageRequest page) async {
    final rows = await _db
        .moviesPage(sourceId: sourceId, limit: page.limit, offset: page.offset)
        .get();
    return Page(
      items: rows.map(_toMovie).toList(growable: false),
      request: page,
    );
  }

  @override
  Future<List<Movie>> moviesInLanguage(
    int sourceId,
    String language,
    PageRequest page,
  ) async {
    final tags = languageTags(language);
    if (tags.isEmpty) return const [];
    final rows = await _db
        .moviesInLanguages(
          sourceId: sourceId,
          tags: tags,
          limit: page.limit,
          offset: page.offset,
        )
        .get();
    return rows.map(_toMovie).toList(growable: false);
  }

  @override
  Future<Movie?> movieById(int movieId) async {
    final row = await _db.movieById(id: movieId).getSingleOrNull();
    return row == null ? null : _toMovie(row);
  }

  @override
  Future<Movie?> movieByContentKey(int sourceId, String contentKey) async {
    final row = await _db
        .movieByContentKey(sourceId: sourceId, contentKey: contentKey)
        .getSingleOrNull();
    return row == null ? null : _toMovie(row);
  }

  @override
  Future<(Series, Episode)?> episodeByContentKey(
    int sourceId,
    String contentKey,
  ) async {
    final row = await _db
        .episodeByContentKey(sourceId: sourceId, contentKey: contentKey)
        .getSingleOrNull();
    if (row == null) return null;
    final series = await seriesById(row.seriesEntryId);
    return series == null ? null : (series, _toEpisode(row));
  }

  @override
  Future<String?> tmdbIdOfEpisode(int sourceId, String contentKey) async {
    final episode = await _db
        .episodeByContentKey(sourceId: sourceId, contentKey: contentKey)
        .getSingleOrNull();
    if (episode == null) return null;
    final entry = await _db
        .seriesEntryById(id: episode.seriesEntryId)
        .getSingleOrNull();
    final id = entry?.tmdbId?.trim();
    // Les panneaux renvoient « 0 » ou une chaîne vide quand ils ne savent pas.
    return id == null || id.isEmpty || id == '0' ? null : id;
  }

  @override
  Future<List<Movie>> moviesByTitleKeys(
    int sourceId,
    Set<String> titleKeys,
  ) async {
    final rows = await _db
        .moviesWithTitleKeys(sourceId: sourceId, keys: titleKeys.toList())
        .get();
    return rows.map(_toMovie).toList(growable: false);
  }

  @override
  Future<Series?> seriesById(int seriesEntryId) async {
    final row = await _db.seriesEntryById(id: seriesEntryId).getSingleOrNull();
    if (row == null) return null;
    return _rawSeries(row, title: row.displayTitle);
  }

  @override
  Future<Map<String, Series>> seriesByTitleKeys(
    int sourceId,
    Set<String> titleKeys, {
    required bool grouped,
    required String language,
  }) async {
    final keys = titleKeys.toList();
    if (keys.isEmpty) return const {};
    final found = <String, Series>{};
    if (!grouped) {
      final rows = await _db
          .seriesRawWithTitleKeys(sourceId: sourceId, keys: keys)
          .get();
      for (final row in versionsByLanguage(
        rows,
        (row) => row.languageTag,
        language,
      )) {
        found.putIfAbsent(row.titleKey, () => _rawSeries(row));
      }
      return found;
    }
    final groups = await _db
        .seriesMergedWithTitleKeys(sourceId: sourceId, keys: keys)
        .get();
    final versions = await _versionsByGroup(sourceId, [
      for (final group in groups) group.seriesKey,
    ]);
    for (final group in groups) {
      final entries = versions[group.seriesKey] ?? const <SeriesEntryRow>[];
      final series = _mergedSeries(group.seriesKey, entries, language);
      for (final entry in entries) {
        if (titleKeys.contains(entry.titleKey)) {
          found.putIfAbsent(entry.titleKey, () => series);
        }
      }
    }
    return found;
  }

  @override
  Future<Page<Series>> series(
    int sourceId,
    PageRequest page, {
    required bool grouped,
    required String language,
  }) async {
    final List<Series> items;
    if (grouped) {
      final groups = await _db
          .seriesMerged(
            sourceId: sourceId,
            limit: page.limit,
            offset: page.offset,
          )
          .get();
      final versions = await _versionsByGroup(sourceId, [
        for (final group in groups) group.seriesKey,
      ]);
      items = [
        for (final group in groups)
          _mergedSeries(
            group.seriesKey,
            versions[group.seriesKey] ?? const [],
            language,
          ),
      ];
    } else {
      final rows = await _db
          .seriesRaw(sourceId: sourceId, limit: page.limit, offset: page.offset)
          .get();
      items = rows.map(_rawSeries).toList(growable: false);
    }
    return Page(items: items, request: page);
  }

  @override
  Future<List<MediaVersion>> versionsOf(
    int sourceId,
    String groupingKey,
  ) async {
    final rows = await _db
        .versionsOfSeries(sourceId: sourceId, seriesKey: groupingKey)
        .get();
    // Un même libellé peut revenir sur plusieurs bouquets : « FR » ne suffirait
    // pas à les distinguer dans le menu.
    final counts = <String, int>{};
    for (final row in rows) {
      final label = row.languageTag ?? row.rawTitle;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return [
      for (final row in rows)
        MediaVersion(
          seriesEntryId: row.id,
          label: row.languageTag ?? row.rawTitle,
          rawTitle: row.rawTitle,
          posterUrl: row.posterUrl,
          variant: counts[row.languageTag ?? row.rawTitle]! > 1
              ? row.category
              : null,
        ),
    ];
  }

  @override
  Future<List<Season>> seasonsOf(int sourceId, int seriesEntryId) async {
    var rows = await _db.episodesForEntry(entryId: seriesEntryId).get();
    if (rows.isEmpty) {
      await _loadXtreamEpisodes(sourceId, seriesEntryId);
      rows = await _db.episodesForEntry(entryId: seriesEntryId).get();
    }

    final seasons = <int, List<Episode>>{};
    for (final row in rows) {
      (seasons[row.season] ??= []).add(_toEpisode(row));
    }
    return [
      for (final entry in seasons.entries)
        Season(number: entry.key, episodes: entry.value),
    ];
  }

  Future<void> _loadXtreamEpisodes(int sourceId, int seriesEntryId) async {
    final entry = await _db
        .seriesEntryById(id: seriesEntryId)
        .getSingleOrNull();
    final seriesId = entry?.xtreamSeriesId;
    if (entry == null || seriesId == null) return;

    final credentials = await _credentials.read(sourceId);
    if (credentials is! XtreamCredentials) {
      throw const AuthFailure('Compte Xtream absent du coffre.');
    }
    final episodes = await XtreamApiClient(
      _client,
      credentials,
    ).seriesEpisodes(seriesId);

    await _db.batch((batch) {
      batch.insertAll(_db.episodes, [
        for (final episode in episodes)
          EpisodesCompanion.insert(
            catalogId: entry.catalogId,
            seriesEntryId: seriesEntryId,
            season: episode.season,
            number: episode.number,
            title: episode.title,
            contentKey: 'x:e:${episode.id}',
            xtreamStreamId: Value(episode.id),
            containerExt: Value(episode.extension),
          ),
      ]);
    });
  }

  Future<Map<String, List<SeriesEntryRow>>> _versionsByGroup(
    int sourceId,
    List<String> keys,
  ) async {
    if (keys.isEmpty) return const {};
    final versions = <String, List<SeriesEntryRow>>{};
    for (final row
        in await _db
            .versionsOfSeriesKeys(sourceId: sourceId, keys: keys)
            .get()) {
      (versions[row.groupingKey] ??= []).add(row);
    }
    return versions;
  }

  /// Série fusionnée : le titre vient de la version la plus proche de [language],
  /// et l'affiche aussi, si cette version en a une.
  Series _mergedSeries(
    String groupingKey,
    List<SeriesEntryRow> versions,
    String language,
  ) {
    final ranked = versionsByLanguage(
      versions,
      (row) => row.languageTag,
      language,
    );
    final best = ranked.first;
    return Series(
      id: best.id,
      title: best.displayTitle,
      groupingKey: groupingKey,
      versionCount: ranked.length,
      year: ranked.map((row) => row.year).nonNulls.firstOrNull,
      posterUrl: ranked.map((row) => row.posterUrl).nonNulls.firstOrNull,
      category: best.category,
    );
  }

  Series _rawSeries(SeriesEntryRow row, {String? title}) => Series(
    id: row.id,
    title: title ?? row.rawTitle,
    groupingKey: row.groupingKey,
    versionCount: 1,
    year: row.year,
    posterUrl: row.posterUrl,
    category: row.category,
  );

  Movie _toMovie(MovieRow row) => Movie(
    id: row.id,
    title: row.displayTitle,
    rawTitle: row.rawTitle,
    contentKey: row.contentKey,
    year: row.year,
    posterUrl: row.posterUrl,
    category: row.category,
    languageTag: row.languageTag,
    locator: LocatorColumns(
      streamUrl: row.streamUrl,
      xtreamStreamId: row.xtreamStreamId,
      containerExt: row.containerExt,
      userAgent: row.userAgent,
      referrer: row.referrer,
    ).toLocator(XtreamNamespace.movie),
  );

  Episode _toEpisode(EpisodeRow row) => Episode(
    id: row.id,
    seriesEntryId: row.seriesEntryId,
    season: row.season,
    number: row.number,
    title: row.title,
    contentKey: row.contentKey,
    locator: LocatorColumns(
      streamUrl: row.streamUrl,
      xtreamStreamId: row.xtreamStreamId,
      containerExt: row.containerExt,
      userAgent: row.userAgent,
      referrer: row.referrer,
    ).toLocator(XtreamNamespace.series),
  );
}
