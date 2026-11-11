import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/catalog_batch.dart';
import '../database/app_database.dart';
import '../database/locator_columns.dart';

/// Écrit un catalogue en base, lot après lot.
///
/// C'est ici que le format commun rencontre les règles de nettoyage : les
/// adapters n'en connaissent aucune.
final class CatalogSession {
  CatalogSession(
    this._db,
    this.catalogId, {
    TitleCleaner cleaner = const TitleCleaner(),
    CountryResolver countryResolver = const CountryResolver(),
  }) : _cleaner = cleaner,
       _countryResolver = countryResolver;

  final AppDatabase _db;
  final TitleCleaner _cleaner;
  final CountryResolver _countryResolver;

  /// Catalogue en cours d'écriture, invisible jusqu'à la bascule finale.
  final int catalogId;

  /// Identifiants des groupes déjà écrits, par nom d'origine.
  final Map<String, int> _groupIds = {};

  /// Analyse des groupes : leurs noms se répètent sur des milliers d'entrées.
  final Map<String, ParsedGroup> _parsedGroups = {};

  /// Versions de séries déjà écrites, pour rattacher leurs épisodes M3U.
  final Map<String, int> _seriesEntryIds = {};

  int _sortOrder = 0;

  /// Écrit un lot dans une transaction courte : les lectures de l'interface
  /// peuvent s'intercaler entre deux lots.
  Future<void> write(CatalogBatch batch) => _db.transaction(() async {
    final channels = <LiveChannelsCompanion>[];
    final movies = <MoviesCompanion>[];
    final episodes = <EpisodesCompanion>[];

    for (final entry in batch.entries) {
      _sortOrder++;
      switch (entry) {
        case LiveEntry():
          channels.add(await _liveRow(entry));
        case MovieEntry():
          movies.add(_movieRow(entry));
        case SeriesEntry():
          await _writeSeries(entry);
        case EpisodeEntry():
          episodes.add(await _episodeRow(entry));
      }
    }

    await _db.batch((batch) {
      batch
        ..insertAll(_db.liveChannels, channels)
        ..insertAll(_db.movies, movies)
        ..insertAll(_db.episodes, episodes);
    });
  });

  /// Oublie ce qu'une section abandonnée avait écrit : ses lignes viennent
  /// d'être supprimées de la base, et leurs identifiants ne valent plus rien.
  void forget(ContentKind? kind) {
    if (kind == null || kind == ContentKind.live) _groupIds.clear();
    if (kind == null || kind == ContentKind.series) _seriesEntryIds.clear();
  }

  Future<LiveChannelsCompanion> _liveRow(LiveEntry entry) async {
    final parsed = _cleaner.parse(entry.rawName, ContentKind.live);
    final group = _parsedGroup(entry.rawGroup);
    final key = GroupingKey.of(parsed.title);
    final locator = LocatorColumns.from(entry.locator);
    return LiveChannelsCompanion.insert(
      catalogId: catalogId,
      groupId: await _groupId(entry.rawGroup, group),
      rawName: entry.rawName,
      displayName: parsed.title,
      groupingKey: key,
      countryCode: Value(
        _countryResolver.resolve(
          tvgCountry: entry.tvgCountry,
          groupCountry: group.countryCode,
          nameCountry: parsed.countryCode,
          tvgId: entry.tvgId,
        ),
      ),
      quality: parsed.quality.index,
      variantLabel: parsed.variantLabel,
      logoUrl: Value(entry.logoUrl),
      epgKey: Value(_epgKey(entry.tvgId, key)),
      streamUrl: Value(locator.streamUrl),
      xtreamStreamId: Value(locator.xtreamStreamId),
      containerExt: Value(locator.containerExt),
      userAgent: Value(locator.userAgent),
      referrer: Value(locator.referrer),
      sortOrder: _sortOrder,
    );
  }

  /// Sans `tvg-id`, le guide est rapproché par le nom de la chaîne.
  String? _epgKey(String? tvgId, String groupingKey) {
    final id = tvgId?.trim().toLowerCase();
    if (id != null && id.isNotEmpty) return id;
    return groupingKey.isEmpty ? null : groupingKey;
  }

  MoviesCompanion _movieRow(MovieEntry entry) {
    final parsed = _cleaner.parse(entry.rawName, ContentKind.movie);
    final group = _parsedGroup(entry.rawGroup);
    final locator = LocatorColumns.from(entry.locator);
    return MoviesCompanion.insert(
      catalogId: catalogId,
      rawTitle: entry.rawName,
      displayTitle: parsed.title,
      titleKey: GroupingKey.of(parsed.title),
      contentKey: _contentKey('m', entry.rawName, locator),
      year: Value(parsed.year),
      languageTag: Value(parsed.language ?? group.language),
      category: Value(_categoryName(entry.rawGroup, group)),
      posterUrl: Value(entry.logoUrl),
      streamUrl: Value(locator.streamUrl),
      xtreamStreamId: Value(locator.xtreamStreamId),
      containerExt: Value(locator.containerExt),
      userAgent: Value(locator.userAgent),
      referrer: Value(locator.referrer),
      sortOrder: _sortOrder,
    );
  }

  Future<int> _writeSeries(SeriesEntry entry) async {
    final parsed = _cleaner.parse(entry.rawName, ContentKind.series);
    return _insertSeriesEntry(
      rawTitle: entry.rawName,
      parsed: parsed,
      entry: entry,
      xtreamSeriesId: entry.xtreamSeriesId,
      tmdbId: entry.tmdbId,
    );
  }

  Future<EpisodesCompanion> _episodeRow(EpisodeEntry entry) async {
    final parsed = _cleaner.parse(entry.rawName, ContentKind.series);
    final group = _parsedGroup(entry.rawGroup);
    final language = parsed.language ?? group.language;
    // L'année distingue deux séries homonymes d'un même groupe.
    final identity =
        '${GroupingKey.of(parsed.title)}|${parsed.year}|$language|'
        '${entry.rawGroup}';
    final entryId = _seriesEntryIds[identity] ??= await _insertSeriesEntry(
      rawTitle: _cleaner.seriesNameOf(entry.rawName),
      parsed: parsed,
      entry: entry,
    );
    final locator = LocatorColumns.from(entry.locator);
    return EpisodesCompanion.insert(
      catalogId: catalogId,
      seriesEntryId: entryId,
      season: parsed.season ?? 1,
      number: parsed.episode ?? 0,
      title: parsed.episodeTitle ?? parsed.title,
      contentKey: _contentKey('e', entry.rawName, locator),
      streamUrl: Value(locator.streamUrl),
      xtreamStreamId: Value(locator.xtreamStreamId),
      containerExt: Value(locator.containerExt),
      userAgent: Value(locator.userAgent),
      referrer: Value(locator.referrer),
    );
  }

  Future<int> _insertSeriesEntry({
    required String rawTitle,
    required ParsedTitle parsed,
    required CatalogEntry entry,
    int? xtreamSeriesId,
    String? tmdbId,
  }) {
    final group = _parsedGroup(entry.rawGroup);
    final titleKey = GroupingKey.of(parsed.title);
    return _db
        .into(_db.seriesEntries)
        .insert(
          SeriesEntriesCompanion.insert(
            catalogId: catalogId,
            rawTitle: rawTitle,
            displayTitle: parsed.title,
            titleKey: titleKey,
            groupingKey: titleKey,
            year: Value(parsed.year),
            languageTag: Value(
              parsed.versionLabel ?? parsed.language ?? group.language,
            ),
            category: Value(_categoryName(entry.rawGroup, group)),
            posterUrl: Value(entry.logoUrl),
            xtreamSeriesId: Value(xtreamSeriesId),
            tmdbId: Value(tmdbId),
            sortOrder: _sortOrder,
          ),
        );
  }

  ParsedGroup _parsedGroup(String rawGroup) =>
      _parsedGroups[rawGroup] ??= _cleaner.parseGroup(rawGroup);

  String? _categoryName(String rawGroup, ParsedGroup group) {
    if (group.displayName.isNotEmpty) return group.displayName;
    return rawGroup.isEmpty ? null : rawGroup;
  }

  Future<int> _groupId(String rawGroup, ParsedGroup group) async {
    final known = _groupIds[rawGroup];
    if (known != null) return known;
    final id = await _db
        .into(_db.channelGroups)
        .insert(
          ChannelGroupsCompanion.insert(
            catalogId: catalogId,
            rawName: rawGroup,
            displayName: group.displayName,
            groupingKey: group.key,
            sortOrder: _groupIds.length,
          ),
        );
    _groupIds[rawGroup] = id;
    return id;
  }

  /// Identité stable : l'identifiant Xtream si possible, sinon le nom d'origine.
  /// Elle relie la progression de lecture au catalogue suivant.
  String _contentKey(String kind, String rawName, LocatorColumns locator) {
    final xtreamId = locator.xtreamStreamId;
    return xtreamId != null ? 'x:$kind:$xtreamId' : 'm:$kind:$rawName';
  }
}
