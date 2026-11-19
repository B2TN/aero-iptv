import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../app_database.dart';
import '../connection.dart';
import 'catalog_maintenance_dao.dart';

/// Lignes examinées par requête : celles de l'interface s'intercalent entre
/// deux passes, la base n'ayant qu'une connexion.
const int _pass = 5000;

// Chaque passe part des lignes du nouveau catalogue (`CROSS JOIN` impose cet
// ordre à SQLite) et trouve leur pendant affiché par son index. Laissé libre,
// SQLite parcourait tout le catalogue affiché à chaque passe.

/// Colonnes d'un film tirées de la playlist. Son résumé, demandé à
/// l'ouverture de sa fiche, n'en fait pas partie : la synchronisation le garde.
const List<String> _movieColumns = [
  'raw_title',
  'display_title',
  'title_key',
  'content_key',
  'year',
  'language_tag',
  'category',
  'poster_url',
  'stream_url',
  'xtream_stream_id',
  'container_ext',
  'user_agent',
  'referrer',
];

/// Colonnes d'une version de série tirées de la playlist, et de ses finitions.
const List<String> _seriesColumns = [
  'raw_title',
  'display_title',
  'title_key',
  'grouping_key',
  'year',
  'language_tag',
  'category',
  'poster_url',
  'xtream_series_id',
  'tmdb_id',
  'entry_key',
  'last_modified',
];

/// Colonnes d'un épisode M3U, hors série et résumé.
const List<String> _episodeColumns = [
  'season',
  'number',
  'title',
  'content_key',
  'stream_url',
  'xtream_stream_id',
  'container_ext',
  'user_agent',
  'referrer',
];

/// Titres d'une table : ceux qui ont disparu, et ceux ajoutés ou changés.
typedef _Changes = ({List<int> removed, List<int> touched});

/// Applique au catalogue affiché les différences d'un catalogue tout juste
/// importé, sans le remplacer : les identifiants des titres restent, avec ce
/// qui y a été chargé depuis (résumés, épisodes Xtream).
///
/// Les favoris et les positions de lecture reposent sur les clés de contenu,
/// jamais sur ces identifiants : la synchronisation ne les touche pas.
final class CatalogMergeDao {
  const CatalogMergeDao(this._db);

  final AppDatabase _db;

  /// Vrai si [catalogId] peut recevoir des différences : ses séries ont une
  /// identité. Un catalogue d'avant la version 7 de la base n'en a pas.
  Future<bool> canMergeInto(int catalogId) async {
    final row = await _db
        .customSelect(
          "SELECT EXISTS (SELECT 1 FROM series_entries "
          "WHERE catalog_id = ?1 AND entry_key = '') AS missing",
          variables: [Variable.withInt(catalogId)],
        )
        .getSingle();
    return !row.read<bool>('missing');
  }

  /// Applique la section [kind] de [fresh] à [shown] ; toutes si `null`.
  ///
  /// [fresh] contient la section entière : ce qui n'y est pas a disparu.
  Future<void> merge(int fresh, int shown, ContentKind? kind) async {
    if (kind == null || kind == ContentKind.live) {
      await replaceLive(fresh, shown);
    }
    if (kind == null || kind == ContentKind.movie) {
      await mergeMovies(fresh, shown);
    }
    if (kind == null || kind == ContentKind.series) {
      await mergeSeries(fresh, shown);
    }
  }

  /// Applique les films de [fresh] à [shown]. Sans [removed], [fresh] les
  /// contient tous ; avec, il ne contient que ceux qui ont changé, et
  /// [removed] nomme ceux qui ont disparu.
  Future<void> mergeMovies(
    int fresh,
    int shown, {
    List<String>? removed,
  }) async {
    final movies = await _mergeTitles(
      table: 'movies',
      key: 'content_key',
      columns: _movieColumns,
      fresh: fresh,
      shown: shown,
      removedKeys: removed,
    );
    await _reindex(
      movies,
      offset: 0,
      insert: CatalogMaintenanceDao.indexMoviesSql,
    );
  }

  /// Applique les séries de [fresh] à [shown], comme [mergeMovies].
  ///
  /// Avec [removed], les versions des séries sont regroupées à nouveau dans
  /// [shown] dès qu'une série a changé : [fresh] n'en contient qu'une partie.
  Future<void> mergeSeries(
    int fresh,
    int shown, {
    List<String>? removed,
  }) async {
    final series = await _mergeTitles(
      table: 'series_entries',
      key: 'entry_key',
      columns: _seriesColumns,
      fresh: fresh,
      shown: shown,
      removedKeys: removed,
      beforeUpdate: (low, high) => _markRefreshed(fresh, shown, low, high),
      beforeDelete: (ids) => _deleteIn('episodes', 'series_entry_id', ids),
    );
    var touched = series.touched;
    if (removed == null) {
      await _mergeEpisodes(fresh, shown);
    } else {
      await _refreshUndated(shown);
      if (series.touched.isNotEmpty || series.removed.isNotEmpty) {
        touched = {...touched, ...await _regroupSeries(shown)}.toList();
      }
    }
    await _reindex(
      (removed: series.removed, touched: touched),
      offset: 1,
      insert: CatalogMaintenanceDao.indexSeriesSql,
    );
  }

  /// Empreintes des titres de [catalogId], par identité : `content_key` d'un
  /// film, `entry_key` d'une série.
  Future<Map<String, int?>> hashesOf(int catalogId, ContentKind kind) async {
    final (table, key) = switch (kind) {
      ContentKind.movie => ('movies', 'content_key'),
      _ => ('series_entries', 'entry_key'),
    };
    final rows = await _db
        .customSelect(
          'SELECT $key AS identity, source_hash AS hash FROM $table '
          'WHERE catalog_id = ?1',
          variables: [Variable.withInt(catalogId)],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('identity'): row.readNullable<int>('hash'),
    };
  }

  /// Empreinte de la liste des chaînes au dernier passage.
  Future<int?> liveHashOf(int sourceId) async {
    final row = await _db
        .customSelect(
          'SELECT live_hash AS hash FROM sources WHERE id = ?1',
          variables: [Variable.withInt(sourceId)],
        )
        .getSingleOrNull();
    return row?.readNullable<int>('hash');
  }

  Future<void> saveLiveHash(int sourceId, int hash) => _db.customStatement(
    'UPDATE sources SET live_hash = ?1 WHERE id = ?2',
    [hash, sourceId],
  );

  /// Une série Xtream qui ne dit jamais quand elle change est redemandée à
  /// chaque synchronisation, à sa prochaine ouverture : rien d'autre ne
  /// signalerait ses nouveaux épisodes.
  Future<void> _refreshUndated(int shown) => _db.customStatement(
    '''
    UPDATE series_entries SET details_loaded = FALSE
    WHERE catalog_id = ?1 AND details_loaded
      AND xtream_series_id IS NOT NULL AND last_modified IS NULL
    ''',
    [shown],
  );

  /// Regroupe les versions des séries de [catalogId] comme à l'import :
  /// titre, année des homonymes, puis titres traduits. Seules les séries
  /// dont la clé change sont réécrites ; retourne leurs identifiants.
  Future<List<int>> _regroupSeries(int catalogId) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT id, title_key, grouping_key, display_title, language_tag,
                 year, poster_url, tmdb_id
          FROM series_entries WHERE catalog_id = ?1
          ''',
          variables: [Variable.withInt(catalogId)],
        )
        .get();
    final years = <String, Set<int>>{};
    for (final row in rows) {
      final year = row.readNullable<int>('year');
      if (year != null) {
        (years[row.read<String>('title_key')] ??= {}).add(year);
      }
    }
    String baseKey(QueryRow row) {
      final title = row.read<String>('title_key');
      final year = row.readNullable<int>('year');
      return year != null && years[title]!.length > 1 ? '$title#$year' : title;
    }

    final merged = VersionGrouper.merge([
      for (final row in rows)
        VersionCandidate(
          groupingKey: baseKey(row),
          title: row.read<String>('display_title'),
          label: row.readNullable<String>('language_tag'),
          year: row.readNullable<int>('year'),
          posterUrl: row.readNullable<String>('poster_url'),
          tmdbId: row.readNullable<String>('tmdb_id'),
        ),
    ]);
    final changed = <({int id, String key})>[];
    for (final row in rows) {
      final base = baseKey(row);
      final key = merged[base] ?? base;
      if (key != row.read<String>('grouping_key')) {
        changed.add((id: row.read<int>('id'), key: key));
      }
    }
    if (changed.isNotEmpty) {
      await transactionKeepingCause(_db, () async {
        for (final row in changed) {
          await _db.customStatement(
            'UPDATE series_entries SET grouping_key = ?1 WHERE id = ?2',
            [row.key, row.id],
          );
        }
      });
    }
    return [for (final row in changed) row.id];
  }

  /// Les chaînes n'ont rien de propre à garder : leur section est remplacée
  /// d'un seul coup, sans moment où la liste serait vide.
  Future<void> replaceLive(int fresh, int shown) =>
      transactionKeepingCause(_db, () async {
        for (final table in ['live_channels', 'channel_groups']) {
          await _db.customStatement(
            'DELETE FROM $table WHERE catalog_id = ?1',
            [shown],
          );
        }
        for (final table in ['channel_groups', 'live_channels']) {
          await _db.customStatement(
            'UPDATE $table SET catalog_id = ?1 WHERE catalog_id = ?2',
            [shown, fresh],
          );
        }
      });

  /// Applique les différences d'une table de titres, reconnus par [key] :
  /// retire ceux qui ont disparu, met à jour ceux qui ont changé, ajoute les
  /// nouveaux.
  Future<_Changes> _mergeTitles({
    required String table,
    required String key,
    required List<String> columns,
    required int fresh,
    required int shown,
    List<String>? removedKeys,
    Future<void> Function(int low, int high)? beforeUpdate,
    Future<void> Function(List<int> ids)? beforeDelete,
  }) async {
    final removed = removedKeys == null
        ? await _vanished(table, key, fresh, shown)
        : await _idsOfKeys(table, key, shown, removedKeys);
    if (removed.isNotEmpty) {
      await beforeDelete?.call(removed);
      await _deleteIn(table, 'id', removed);
    }

    final touched = <int>[];
    final differs = [
      for (final column in columns) 'a.$column IS NOT s.$column',
    ].join(' OR ');
    final list = columns.join(', ');
    final selected = [for (final column in columns) 's.$column'].join(', ');
    // Le pendant d'une ligne affichée, dans le nouveau catalogue.
    final counterpart =
        'FROM $table AS s WHERE s.catalog_id = ?1 AND s.$key = $table.$key';
    final matched =
        'SELECT a.id FROM $table AS s CROSS JOIN $table AS a '
        'ON a.catalog_id = ?4 AND a.$key = s.$key '
        'WHERE s.catalog_id = ?1 AND s.id BETWEEN ?2 AND ?3';
    await _passes(table, fresh, (low, high) async {
      final variables = [fresh, low, high, shown];
      await beforeUpdate?.call(low, high);
      touched.addAll(
        await _ids(
          'UPDATE $table SET ($list) = (SELECT $selected $counterpart) '
          'WHERE id IN ($matched AND ($differs)) RETURNING id',
          variables,
        ),
      );
      // L'ordre du fournisseur et l'empreinte bougent sans que le titre
      // change : la recherche n'a pas à le savoir.
      await _db.customStatement(
        'UPDATE $table SET (sort_order, source_hash) = '
        '(SELECT s.sort_order, s.source_hash $counterpart) '
        'WHERE id IN ($matched AND (a.sort_order IS NOT s.sort_order '
        'OR a.source_hash IS NOT s.source_hash))',
        variables,
      );
      touched.addAll(
        await _ids(
          'INSERT INTO $table (catalog_id, $list, sort_order, source_hash) '
          'SELECT ?4, $selected, s.sort_order, s.source_hash FROM $table AS s '
          'WHERE s.catalog_id = ?1 AND s.id BETWEEN ?2 AND ?3 '
          'AND NOT EXISTS (SELECT 1 FROM $table AS a '
          'WHERE a.catalog_id = ?4 AND a.$key = s.$key) '
          'RETURNING id',
          variables,
        ),
      );
    });
    return (removed: removed, touched: touched);
  }

  /// Une série Xtream modifiée chez le fournisseur, ou qui ne dit pas quand,
  /// est redemandée à sa prochaine ouverture : ses nouveaux épisodes s'y
  /// ajoutent. Ses épisodes connus restent, pour « Continuer à regarder ».
  Future<void> _markRefreshed(int fresh, int shown, int low, int high) =>
      _db.customStatement(
        '''
    UPDATE series_entries SET details_loaded = FALSE WHERE id IN (
      SELECT a.id FROM series_entries AS s CROSS JOIN series_entries AS a
        ON a.catalog_id = ?4 AND a.entry_key = s.entry_key
      WHERE s.catalog_id = ?1 AND s.id BETWEEN ?2 AND ?3
        AND a.xtream_series_id IS NOT NULL AND a.details_loaded
        AND (s.last_modified IS NULL OR a.last_modified IS NOT s.last_modified)
    )
    ''',
        [fresh, low, high, shown],
      );

  /// Épisodes d'une playlist M3U, venus avec elle. Ceux d'une série Xtream,
  /// chargés à l'ouverture, n'y figurent pas et restent.
  Future<void> _mergeEpisodes(int fresh, int shown) async {
    final removed = <int>[];
    var last = 0;
    while (true) {
      final rows = await _db
          .customSelect(
            '''
            SELECT a.id AS id, NOT EXISTS (
              SELECT 1 FROM episodes AS s
              WHERE s.catalog_id = ?2 AND s.content_key = a.content_key
            ) AS gone
            FROM episodes AS a
            WHERE a.catalog_id = ?1 AND a.xtream_stream_id IS NULL
              AND a.id > ?3
            ORDER BY a.id LIMIT $_pass
            ''',
            variables: [
              Variable.withInt(shown),
              Variable.withInt(fresh),
              Variable.withInt(last),
            ],
          )
          .get();
      for (final row in rows) {
        if (row.read<bool>('gone')) removed.add(row.read<int>('id'));
      }
      if (rows.length < _pass) break;
      last = rows.last.read<int>('id');
    }
    await _deleteIn('episodes', 'id', removed);

    // La série affichée d'un épisode du nouveau catalogue, par son identité.
    const series = '''
      CROSS JOIN series_entries AS ss ON ss.id = s.series_entry_id
      CROSS JOIN series_entries AS ae
        ON ae.catalog_id = ?4 AND ae.entry_key = ss.entry_key''';
    final differs = [
      for (final column in _episodeColumns) 'a.$column IS NOT s.$column',
      'a.series_entry_id IS NOT ae.id',
    ].join(' OR ');
    final list = _episodeColumns.join(', ');
    final selected = [
      for (final column in _episodeColumns) 's.$column',
    ].join(', ');
    await _passes('episodes', fresh, (low, high) async {
      final variables = [fresh, low, high, shown];
      await _db.customStatement(
        'UPDATE episodes SET ($list, series_entry_id) = '
        '(SELECT $selected, ae.id FROM episodes AS s $series '
        'WHERE s.catalog_id = ?1 AND s.content_key = episodes.content_key) '
        'WHERE id IN (SELECT a.id FROM episodes AS s $series '
        'CROSS JOIN episodes AS a '
        'ON a.catalog_id = ?4 AND a.content_key = s.content_key '
        'WHERE s.catalog_id = ?1 AND s.id BETWEEN ?2 AND ?3 '
        'AND ($differs))',
        variables,
      );
      await _db.customStatement(
        'INSERT INTO episodes (catalog_id, series_entry_id, $list) '
        'SELECT ?4, ae.id, $selected FROM episodes AS s $series '
        'WHERE s.catalog_id = ?1 AND s.id BETWEEN ?2 AND ?3 '
        'AND NOT EXISTS (SELECT 1 FROM episodes AS a '
        'WHERE a.catalog_id = ?4 AND a.content_key = s.content_key)',
        variables,
      );
    });
  }

  /// Titres de [catalogId] dont l'identité est parmi [keys].
  Future<List<int>> _idsOfKeys(
    String table,
    String key,
    int catalogId,
    List<String> keys,
  ) async {
    final ids = <int>[];
    for (var start = 0; start < keys.length; start += _pass) {
      final chunk = keys.skip(start).take(_pass).toList();
      final rows = await _db
          .customSelect(
            'SELECT id FROM $table WHERE catalog_id = ?1 AND $key IN '
            '(${List.filled(chunk.length, '?').join(', ')})',
            variables: [
              Variable.withInt(catalogId),
              for (final value in chunk) Variable.withString(value),
            ],
          )
          .get();
      ids.addAll([for (final row in rows) row.read<int>('id')]);
    }
    return ids;
  }

  /// Titres de [shown] absents de [fresh].
  Future<List<int>> _vanished(
    String table,
    String key,
    int fresh,
    int shown,
  ) async {
    final gone = <int>[];
    var last = 0;
    while (true) {
      final rows = await _db
          .customSelect(
            '''
            SELECT a.id AS id, NOT EXISTS (
              SELECT 1 FROM $table AS s
              WHERE s.catalog_id = ?2 AND s.$key = a.$key
            ) AS gone
            FROM $table AS a
            WHERE a.catalog_id = ?1 AND a.id > ?3
            ORDER BY a.id LIMIT $_pass
            ''',
            variables: [
              Variable.withInt(shown),
              Variable.withInt(fresh),
              Variable.withInt(last),
            ],
          )
          .get();
      for (final row in rows) {
        if (row.read<bool>('gone')) gone.add(row.read<int>('id'));
      }
      if (rows.length < _pass) return gone;
      last = rows.last.read<int>('id');
    }
  }

  /// Parcourt les lignes de [catalogId] par tranches d'identifiants : un
  /// catalogue tout juste importé les a à la suite.
  Future<void> _passes(
    String table,
    int catalogId,
    Future<void> Function(int low, int high) pass,
  ) async {
    final bounds = await _db
        .customSelect(
          'SELECT MIN(id) AS low, MAX(id) AS high FROM $table '
          'WHERE catalog_id = ?1',
          variables: [Variable.withInt(catalogId)],
        )
        .getSingle();
    final low = bounds.readNullable<int>('low');
    final high = bounds.readNullable<int>('high');
    if (low == null || high == null) return;
    for (var start = low; start <= high; start += _pass) {
      await pass(start, start + _pass - 1);
    }
  }

  /// Retire et réécrit les lignes de recherche des titres changés : chacune a
  /// pour numéro le double de l'identifiant du titre, plus [offset].
  Future<void> _reindex(
    _Changes changes, {
    required int offset,
    required String insert,
  }) async {
    final stale = [...changes.removed, ...changes.touched];
    for (var start = 0; start < stale.length; start += _pass) {
      final ids = stale.skip(start).take(_pass).toList();
      await _db.customStatement(
        'DELETE FROM search_index WHERE rowid IN '
        '(${[for (final id in ids) id * 2 + offset].join(', ')})',
      );
    }
    for (var start = 0; start < changes.touched.length; start += _pass) {
      final ids = changes.touched.skip(start).take(_pass).join(', ');
      await _db.customStatement('$insert WHERE id IN ($ids)');
    }
  }

  Future<void> _deleteIn(String table, String column, List<int> ids) async {
    for (var start = 0; start < ids.length; start += _pass) {
      final chunk = ids.skip(start).take(_pass).join(', ');
      await _db.customStatement('DELETE FROM $table WHERE $column IN ($chunk)');
    }
  }

  /// Identifiants rendus par une écriture `RETURNING`.
  Future<List<int>> _ids(String sql, List<int> variables) async => [
    for (final row
        in await _db
            .customSelect(
              sql,
              variables: [
                for (final value in variables) Variable.withInt(value),
              ],
            )
            .get())
      row.read<int>('id'),
  ];
}
