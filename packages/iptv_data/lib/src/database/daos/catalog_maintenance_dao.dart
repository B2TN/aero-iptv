import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../app_database.dart';

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
    await _db.transaction(() async {
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
    await _db.customStatement(
      '''
      INSERT INTO search_index (title, group_key, kind, ref_id, catalog_id, poster_url)
      SELECT display_title, 'm' || title_key, 1, id, catalog_id, poster_url
      FROM movies WHERE catalog_id = ?1
      ''',
      [catalogId],
    );
    await _db.customStatement(
      '''
      INSERT INTO search_index (title, group_key, kind, ref_id, catalog_id, poster_url)
      SELECT display_title, 's' || grouping_key, 2, id, catalog_id, poster_url
      FROM series_entries WHERE catalog_id = ?1
      ''',
      [catalogId],
    );
  }

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
