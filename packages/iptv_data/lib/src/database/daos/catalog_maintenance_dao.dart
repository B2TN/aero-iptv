import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../app_database.dart';
import '../connection.dart';

/// Lignes supprimées à chaque passe : les requêtes de l'interface peuvent
/// s'intercaler entre deux passes.
const int _purgeChunkSize = 5000;

/// Tables de chaque section, dans l'ordre où les vider : un épisode référence
/// sa série, et une chaîne son groupe.
const Map<ContentKind, List<String>> _sectionTables = {
  ContentKind.series: ['episodes', 'series_entries'],
  ContentKind.movie: ['movies'],
  ContentKind.live: ['live_channels', 'channel_groups'],
};

/// Opérations sur un catalogue entier.
final class CatalogMaintenanceDao {
  const CatalogMaintenanceDao(this._db);

  final AppDatabase _db;

  /// Réserve un catalogue vide, invisible tant qu'il n'est pas activé.
  Future<int> create(int sourceId, DateTime now) => _db
      .into(_db.catalogs)
      .insert(
        CatalogsCompanion.insert(
          sourceId: sourceId,
          createdAt: now.millisecondsSinceEpoch,
        ),
      );

  /// Sépare les séries homonymes : si un titre existe avec plusieurs années,
  /// l'année entre dans la clé. Une version sans année reste sur la clé du titre.
  Future<void> separateHomonyms(int catalogId) => _db.customStatement(
    '''
    UPDATE series_entries
    SET grouping_key = title_key || '#' || year
    WHERE catalog_id = ?1 AND year IS NOT NULL AND title_key IN (
      SELECT title_key FROM series_entries
      WHERE catalog_id = ?1 AND year IS NOT NULL
      GROUP BY title_key
      HAVING COUNT(DISTINCT year) > 1
    )
    ''',
    [catalogId],
  );

  /// Relie les versions de titres traduits, reconnues à leur identifiant TMDb
  /// ou à leur affiche.
  Future<void> mergeTranslatedVersions(int catalogId) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT grouping_key, display_title, language_tag, year, poster_url,
                 tmdb_id
          FROM series_entries WHERE catalog_id = ?1
          ''',
          variables: [Variable.withInt(catalogId)],
        )
        .get();
    final merged = VersionGrouper.merge(
      rows.map(
        (row) => VersionCandidate(
          groupingKey: row.read<String>('grouping_key'),
          title: row.read<String>('display_title'),
          label: row.readNullable<String>('language_tag'),
          year: row.readNullable<int>('year'),
          posterUrl: row.readNullable<String>('poster_url'),
          tmdbId: row.readNullable<String>('tmdb_id'),
        ),
      ),
    );
    await transactionKeepingCause(_db, () async {
      for (final entry in merged.entries) {
        await _db.customStatement(
          '''
          UPDATE series_entries SET grouping_key = ?1
          WHERE catalog_id = ?2 AND grouping_key = ?3
          ''',
          [entry.value, catalogId, entry.key],
        );
      }
    });
  }

  /// Construit l'index de recherche des films et des séries.
  Future<void> buildSearchIndex(int catalogId) async {
    await _db.customStatement('$indexMoviesSql WHERE catalog_id = ?1', [
      catalogId,
    ]);
    await _db.customStatement('$indexSeriesSql WHERE catalog_id = ?1', [
      catalogId,
    ]);
  }

  /// Ajoute des films à l'index de recherche ; le `WHERE` choisit lesquels.
  static const String indexMoviesSql = '''
    INSERT INTO search_index
      (rowid, title, group_key, kind, ref_id, catalog_id, poster_url)
    SELECT id * 2, display_title, 'm' || title_key, 1, id, catalog_id,
           poster_url
    FROM movies''';

  /// Ajoute des séries à l'index de recherche ; le `WHERE` choisit lesquelles.
  static const String indexSeriesSql = '''
    INSERT INTO search_index
      (rowid, title, group_key, kind, ref_id, catalog_id, poster_url)
    SELECT id * 2 + 1, display_title, 's' || grouping_key, 2, id, catalog_id,
           poster_url
    FROM series_entries''';

  /// Active [catalogId] en une seule écriture.
  ///
  /// Le changement de valeur suffit à basculer toutes les requêtes de lecture.
  /// Retourne l'ancien catalogue, à supprimer ensuite.
  Future<int?> activate(int sourceId, int catalogId, DateTime now) =>
      _db.transaction(() async {
        final source = await (_db.select(
          _db.sources,
        )..where((row) => row.id.equals(sourceId))).getSingle();
        await (_db.update(
          _db.sources,
        )..where((row) => row.id.equals(sourceId))).write(
          SourcesCompanion(
            activeCatalogId: Value(catalogId),
            lastSyncedAt: Value(now.millisecondsSinceEpoch),
          ),
        );
        return source.activeCatalogId;
      });

  /// Note la synchronisation de [sourceId], dont le catalogue reste le même.
  Future<void> markSynced(int sourceId, DateTime now) =>
      (_db.update(_db.sources)..where((row) => row.id.equals(sourceId))).write(
        SourcesCompanion(lastSyncedAt: Value(now.millisecondsSinceEpoch)),
      );

  /// Catalogue affiché pour [sourceId], s'il y en a un.
  Future<int?> activeCatalogOf(int sourceId) async {
    final source = await (_db.select(
      _db.sources,
    )..where((row) => row.id.equals(sourceId))).getSingleOrNull();
    return source?.activeCatalogId;
  }

  /// Vide une section d'un catalogue par petites passes. [kind] à `null` les
  /// vide toutes.
  Future<void> purgeSection(int catalogId, ContentKind? kind) async {
    final tables = kind == null
        ? _sectionTables.values.expand((tables) => tables)
        : _sectionTables[kind]!;
    for (final table in tables) {
      int deleted;
      do {
        deleted = await _db.customUpdate(
          'DELETE FROM $table WHERE rowid IN '
          '(SELECT rowid FROM $table WHERE catalog_id = ? LIMIT $_purgeChunkSize)',
          variables: [Variable.withInt(catalogId)],
          updateKind: UpdateKind.delete,
        );
      } while (deleted == _purgeChunkSize);
    }
  }

  /// Fait passer la section [kind] de [fromCatalogId] à [toCatalogId] : une
  /// section que le serveur refuse garde ainsi son contenu précédent.
  Future<void> carryOver(
    int fromCatalogId,
    int toCatalogId,
    ContentKind kind,
  ) async {
    for (final table in _sectionTables[kind]!) {
      await _db.customStatement(
        'UPDATE $table SET catalog_id = ?1 WHERE catalog_id = ?2',
        [toCatalogId, fromCatalogId],
      );
    }
  }

  /// Garde, d'un catalogue à celui qui le remplace en entier, ce qui a été
  /// chargé à l'ouverture des titres : les résumés des films et des séries,
  /// et les épisodes des séries Xtream. « Continuer à regarder » retrouve
  /// ainsi ses épisodes, et leurs fiches restent complètes.
  ///
  /// Une série modifiée depuis chez le fournisseur garde ses épisodes, mais
  /// sera redemandée à sa prochaine ouverture, pour ajouter les nouveaux.
  Future<void> carryLoaded(int fromCatalogId, int toCatalogId) async {
    final ids = [fromCatalogId, toCatalogId];
    await _db.customStatement('''
      UPDATE movies
      SET (overview, genre, runtime_minutes, details_loaded) = (
        SELECT o.overview, o.genre, o.runtime_minutes, TRUE FROM movies AS o
        WHERE o.catalog_id = ?1 AND o.content_key = movies.content_key
          AND o.details_loaded
        LIMIT 1)
      WHERE id IN (
        SELECT n.id FROM movies AS o CROSS JOIN movies AS n
          ON n.catalog_id = ?2 AND n.content_key = o.content_key
        WHERE o.catalog_id = ?1 AND o.details_loaded)
      ''', ids);
    // Les séries Xtream se reconnaissent à leur identifiant chez le
    // fournisseur : un catalogue d'avant la version 7 n'a pas d'identité.
    const counterpart = '''
      CROSS JOIN series_entries AS n
        ON n.catalog_id = ?2 AND n.entry_key = 'x:s:' || o.xtream_series_id''';
    await _db.customStatement('''
      UPDATE series_entries
      SET (overview, genre, runtime_minutes, details_loaded) = (
        SELECT o.overview, o.genre, o.runtime_minutes,
               o.last_modified IS series_entries.last_modified
        FROM series_entries AS o
        WHERE o.catalog_id = ?1
          AND 'x:s:' || o.xtream_series_id = series_entries.entry_key
          AND o.details_loaded
        LIMIT 1)
      WHERE id IN (
        SELECT n.id FROM series_entries AS o $counterpart
        WHERE o.catalog_id = ?1 AND o.xtream_series_id IS NOT NULL
          AND o.details_loaded)
      ''', ids);
    await _db.customStatement('''
      INSERT INTO episodes (catalog_id, series_entry_id, season, number, title,
        content_key, stream_url, xtream_stream_id, container_ext, user_agent,
        referrer, overview)
      SELECT ?2, n.id, e.season, e.number, e.title, e.content_key,
             e.stream_url, e.xtream_stream_id, e.container_ext, e.user_agent,
             e.referrer, e.overview
      FROM series_entries AS o
      CROSS JOIN episodes AS e ON e.series_entry_id = o.id
      $counterpart
      WHERE o.catalog_id = ?1 AND o.xtream_series_id IS NOT NULL
      ''', ids);
  }

  /// Supprime un catalogue par petites passes.
  Future<void> purge(int catalogId) async {
    await purgeSection(catalogId, null);
    await _db.customStatement(
      'DELETE FROM search_index WHERE catalog_id = ?1',
      [catalogId],
    );
    await (_db.delete(
      _db.catalogs,
    )..where((row) => row.id.equals(catalogId))).go();
  }

  /// Supprime les catalogues laissés par un import interrompu.
  Future<void> purgeOrphans() async {
    final orphans = await _db.orphanCatalogs().get();
    for (final catalogId in orphans) {
      await purge(catalogId);
    }
  }

  /// Supprime tous les catalogues d'une source.
  Future<void> purgeSource(int sourceId) async {
    final catalogs = await _db.catalogsOfSource(sourceId: sourceId).get();
    for (final catalogId in catalogs) {
      await purge(catalogId);
    }
  }
}
