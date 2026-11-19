import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../app_database.dart';
import '../connection.dart';
import 'catalog_maintenance_dao.dart';

/// Lignes examinées par requête : celles de l'interface s'intercalent entre
/// deux passes, la base n'ayant qu'une connexion.
const int _pass = 5000;

/// Valeurs par liste `IN` d'une requête.
const int _inChunk = 500;

/// Tours d'exploration autour des films changés : chacun ajoute les versions
/// qui partagent un titre, une fiche, un identifiant TMDb ou une affiche
/// avec celles déjà trouvées.
const int _neighbourRounds = 4;

/// Au-delà de tant de films changés, ou de voisins trouvés, tout le
/// catalogue est regroupé d'un coup : l'exploration coûterait plus cher.
const int _maxChanged = 5000;
const int _maxNeighbourhood = 20000;

/// Nom du fichier d'une affiche : ce qui suit sa dernière barre oblique.
const String _posterFileSql =
    "replace(poster_url, rtrim(poster_url, replace(poster_url, '/', '')), '')";

// Chaque passe part des lignes du nouveau catalogue (`CROSS JOIN` impose cet
// ordre à SQLite) et trouve leur pendant affiché par son index. Laissé libre,
// SQLite parcourait tout le catalogue affiché à chaque passe.

/// Colonnes d'un film tirées de la playlist. Son résumé, demandé à
/// l'ouverture de sa fiche, n'en fait pas partie : la synchronisation le garde.
const List<String> _movieColumns = [
  'raw_title',
  'display_title',
  'title_key',
  'grouping_key',
  'tmdb_id',
  'quality',
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

/// Valeurs d'une colonne à chercher autour des films changés.
final class _Leads {
  final Set<String> wanted = {};
  final Set<String> _asked = {};

  /// Valeurs pas encore cherchées, par lots, aussitôt notées comme cherchées.
  Iterable<List<String>> next() {
    final values = wanted.difference(_asked).toList();
    _asked.addAll(values);
    return [
      for (var start = 0; start < values.length; start += _inChunk)
        values.skip(start).take(_inChunk).toList(),
    ];
  }
}

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
  ///
  /// Avec [removed], les fiches des films changés sont recomposées dans
  /// [shown], avec leurs voisins : [fresh] n'en contient qu'une partie.
  Future<void> mergeMovies(
    int fresh,
    int shown, {
    List<String>? removed,
  }) async {
    // Fiches que les changements peuvent défaire : celles des films retirés
    // ou modifiés, avant qu'ils ne le soient.
    final stale = <String>{};
    final partial = removed != null;
    final movies = await _mergeTitles(
      table: 'movies',
      key: 'content_key',
      columns: _movieColumns,
      fresh: fresh,
      shown: shown,
      removedKeys: removed,
      beforeUpdate: partial
          ? (low, high) async => stale.addAll(
              await _groupsOfCounterparts(fresh, shown, low, high),
            )
          : null,
      beforeDelete: partial
          ? (ids) async => stale.addAll(await _groupsOfMovies(ids))
          : null,
    );
    var touched = movies.touched;
    if (partial && (movies.touched.isNotEmpty || movies.removed.isNotEmpty)) {
      touched = {
        ...touched,
        ...await _regroupMovies(shown, movies.touched, stale),
      }.toList();
    }
    await _reindex(
      (removed: movies.removed, touched: touched),
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

  /// Enregistre les empreintes [hashes] des films de [catalogId] qui n'en
  /// avaient pas encore, sans rien d'autre : ils viennent d'un catalogue
  /// importé avant les empreintes, et sont tenus pour inchangés.
  Future<void> backfillMovieHashes(
    int catalogId,
    List<(String, int)> hashes,
  ) async {
    const chunk = 500;
    for (var start = 0; start < hashes.length; start += chunk) {
      final pairs = hashes.skip(start).take(chunk).toList();
      await _db.customStatement(
        'UPDATE movies SET source_hash = CASE content_key '
        '${List.filled(pairs.length, 'WHEN ? THEN ?').join(' ')} END '
        'WHERE catalog_id = ? AND source_hash IS NULL AND content_key IN '
        '(${List.filled(pairs.length, '?').join(', ')})',
        [
          for (final (key, hash) in pairs) ...[key, hash],
          catalogId,
          for (final (key, _) in pairs) key,
        ],
      );
    }
  }

  /// Retire de [catalogId] les lignes de séparation (`##### MAROC #####`)
  /// gardées d'avant leur exclusion : elles ne sont pas des titres.
  Future<void> removeHeaderEntries(int catalogId, TitleCleaner cleaner) async {
    for (final (table, offset) in [('movies', 0), ('series_entries', 1)]) {
      // Une ligne de séparation commence par un signe : les autres titres
      // ne passent pas par le nettoyeur.
      final rows = await _db
          .customSelect(
            "SELECT id, raw_title FROM $table WHERE catalog_id = ?1 "
            "AND raw_title NOT GLOB '[A-Za-z0-9]*'",
            variables: [Variable.withInt(catalogId)],
          )
          .get();
      final ids = [
        for (final row in rows)
          if (cleaner.isHeaderEntry(row.read<String>('raw_title')))
            row.read<int>('id'),
      ];
      if (ids.isEmpty) continue;
      if (table == 'series_entries') {
        await _deleteIn('episodes', 'series_entry_id', ids);
      }
      await _reindex(
        (removed: ids, touched: const <int>[]),
        offset: offset,
        insert: '',
      );
      await _deleteIn(table, 'id', ids);
    }
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
  Future<List<int>> _regroupSeries(int catalogId) async => _writeKeys(
    'series_entries',
    regroupedKeys(await _allOf('series_entries', catalogId), franchises: true),
  );

  /// Recompose les fiches autour des films [changed] de [catalogId], et de
  /// celles nommées [stale] : les autres n'ont pas pu bouger. Retourne les
  /// films dont la fiche change.
  Future<List<int>> _regroupMovies(
    int catalogId,
    List<int> changed,
    Set<String> stale,
  ) async {
    final rows = changed.length > _maxChanged
        ? null
        : await _neighbourhood(catalogId, changed, stale);
    return _writeKeys(
      'movies',
      regroupedKeys(
        rows ?? await _allOf('movies', catalogId),
        franchises: false,
      ),
    );
  }

  /// Films de [catalogId] liés de proche en proche à [changed] et aux
  /// fiches [stale] : même titre, même fiche, même identifiant TMDb ou même
  /// affiche. `null` s'ils sont trop nombreux.
  Future<List<QueryRow>?> _neighbourhood(
    int catalogId,
    List<int> changed,
    Set<String> stale,
  ) async {
    final found = <int, QueryRow>{};
    final titles = _Leads();
    final groups = _Leads()..wanted.addAll(stale);
    final tmdbIds = _Leads();
    final posters = _Leads();

    void add(List<QueryRow> rows) {
      for (final row in rows) {
        if (found.containsKey(row.read<int>('id'))) continue;
        found[row.read<int>('id')] = row;
        titles.wanted.add(row.read<String>('title_key'));
        groups.wanted.add(row.read<String>('grouping_key'));
        final tmdb = row.readNullable<String>('tmdb_id')?.trim();
        if (tmdb != null && tmdb.isNotEmpty && tmdb != '0') {
          tmdbIds.wanted.add(tmdb);
        }
        final poster = _posterFile(row.readNullable<String>('poster_url'));
        if (poster != null) posters.wanted.add(poster);
      }
    }

    for (var start = 0; start < changed.length; start += _inChunk) {
      final ids = changed.skip(start).take(_inChunk).join(', ');
      add(await _moviesWhere(catalogId, 'id IN ($ids)'));
    }
    for (var round = 0; round < _neighbourRounds; round++) {
      // Titres et fiches d'abord : leurs index répondent tout de suite.
      for (final (column, leads) in [
        ('title_key', titles),
        ('grouping_key', groups),
      ]) {
        for (final chunk in leads.next()) {
          add(
            await _moviesWhere(
              catalogId,
              '$column IN ${_slots(chunk.length)}',
              chunk,
            ),
          );
        }
      }
      // Identifiants TMDb et affiches ensuite, en un seul parcours du
      // catalogue par lot : aucun index ne les couvre. Une affiche se
      // reconnaît au nom de son fichier, comme le fait `VersionGrouper`.
      final tmdbChunks = tmdbIds.next().toList();
      final posterChunks = posters.next().toList();
      if (tmdbChunks.isEmpty && posterChunks.isEmpty) break;
      for (var i = 0; i < tmdbChunks.length || i < posterChunks.length; i++) {
        final tmdb = i < tmdbChunks.length ? tmdbChunks[i] : const <String>[];
        final poster = i < posterChunks.length
            ? posterChunks[i]
            : const <String>[];
        add(
          await _moviesWhere(
            catalogId,
            'tmdb_id IN ${_slots(tmdb.length)} '
            'OR $_posterFileSql IN ${_slots(poster.length)}',
            [...tmdb, ...poster],
          ),
        );
        if (found.length > _maxNeighbourhood) return null;
      }
    }
    // Les titres trouvés en dernier ont peut-être d'autres années, qui
    // décident pourtant de leur fiche.
    for (final chunk in titles.next()) {
      add(
        await _moviesWhere(
          catalogId,
          'title_key IN ${_slots(chunk.length)}',
          chunk,
        ),
      );
    }
    return found.length > _maxNeighbourhood ? null : found.values.toList();
  }

  /// Versions de [catalogId] qui répondent à [where], dont les paramètres
  /// valent [values].
  Future<List<QueryRow>> _moviesWhere(
    int catalogId,
    String where, [
    List<String> values = const [],
  ]) => _db
      .customSelect(
        'SELECT $groupingColumns FROM movies '
        'WHERE catalog_id = ?1 AND ($where)',
        variables: [
          Variable.withInt(catalogId),
          for (final value in values) Variable.withString(value),
        ],
      )
      .get();

  /// Liste SQL de [count] paramètres ; `(NULL)` si elle est vide, qui ne
  /// correspond à rien.
  static String _slots(int count) =>
      count == 0 ? '(NULL)' : '(${List.filled(count, '?').join(', ')})';

  Future<List<QueryRow>> _allOf(String table, int catalogId) => _db
      .customSelect(
        'SELECT $groupingColumns FROM $table WHERE catalog_id = ?1',
        variables: [Variable.withInt(catalogId)],
      )
      .get();

  /// Écrit les nouvelles fiches [keys] de [table] ; retourne les titres
  /// concernés.
  Future<List<int>> _writeKeys(String table, Map<int, String> keys) async {
    await writeGroupingKeys(_db, table, keys);
    return keys.keys.toList();
  }

  /// Fiches des films affichés que la passe [low]..[high] de [fresh] va
  /// modifier.
  Future<List<String>> _groupsOfCounterparts(
    int fresh,
    int shown,
    int low,
    int high,
  ) async => [
    for (final row
        in await _db
            .customSelect(
              'SELECT DISTINCT a.grouping_key AS grouping_key '
              'FROM movies AS s CROSS JOIN movies AS a '
              'ON a.catalog_id = ?4 AND a.content_key = s.content_key '
              'WHERE s.catalog_id = ?1 AND s.id BETWEEN ?2 AND ?3',
              variables: [
                for (final value in [fresh, low, high, shown])
                  Variable.withInt(value),
              ],
            )
            .get())
      row.read<String>('grouping_key'),
  ];

  Future<List<String>> _groupsOfMovies(List<int> ids) async => [
    for (var start = 0; start < ids.length; start += _pass)
      for (final row
          in await _db
              .customSelect(
                'SELECT DISTINCT grouping_key FROM movies WHERE id IN '
                '(${ids.skip(start).take(_pass).join(', ')})',
              )
              .get())
        row.read<String>('grouping_key'),
  ];

  /// Nom du fichier d'une affiche TMDb, seul indice que `VersionGrouper`
  /// en retient.
  static String? _posterFile(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.host.contains('tmdb') && !uri.host.contains('themoviedb')) {
      return null;
    }
    final slash = url.lastIndexOf('/');
    return slash < 0 || slash == url.length - 1
        ? null
        : url.substring(slash + 1);
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
