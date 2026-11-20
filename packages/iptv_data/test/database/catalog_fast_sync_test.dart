import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart' hide AppDatabase;
import 'package:iptv_data/src/adapters/xtream/raw_entry.dart';
import 'package:iptv_data/src/adapters/xtream/xtream_source_adapter.dart';
import 'package:iptv_data/src/database/app_database.dart'
    hide AppSettings, WatchProgress;
import 'package:iptv_data/src/import/catalog_import_pipeline.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

const XtreamCredentials _xtream = XtreamCredentials(
  serverUrl: 'http://s.example',
  username: 'u',
  password: 'p',
);

/// Panneau Xtream en mémoire, que chaque test modifie entre deux
/// synchronisations.
final class _Panel {
  final Map<int, String> channels = {1: 'FR: TF1', 2: 'FR: France 2'};
  final Map<int, String> movies = {10: 'FR - Dune', 11: 'FR - Alien'};

  /// Identifiants TMDb et affiches des films qui en ont.
  final Map<int, String> movieTmdb = {};
  final Map<int, String> moviePosters = {};

  /// Séries : nom, date de modification, identifiant TMDb.
  final Map<int, (String, int, String)> series = {
    20: ('FR - Lost', 100, '4607'),
  };
  final List<String> asked = [];

  /// Note que le panneau recalcule : l'application ne la lit pas.
  String rating = '7.1';

  static const Map<String, String> categories = {
    '1': 'FR| TNT',
    '2': 'FILMS',
    '3': 'SERIES',
  };

  Map<String, Object?> movie(int id, int num) => {
    'num': num,
    'name': movies[id],
    'stream_id': id,
    'category_id': '2',
    'rating': rating,
    'container_extension': 'mkv',
    'tmdb': ?movieTmdb[id],
    'stream_icon': ?moviePosters[id],
  };

  Map<String, Object?> show(int id, int num) {
    final (name, modified, tmdb) = series[id]!;
    return {
      'num': num,
      'name': name,
      'series_id': id,
      'category_id': '3',
      'rating': rating,
      'last_modified': '$modified',
      'tmdb': tmdb,
    };
  }

  http.Response _json(Object body) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

  http.Response answer(http.Request request) {
    final action = request.url.queryParameters['action'];
    asked.add(action ?? 'connexion');
    var num = 0;
    return switch (action) {
      null => _json({
        'user_info': {'auth': 1, 'status': 'Active'},
      }),
      'get_live_streams' => _json([
        for (final MapEntry(key: id, value: name) in channels.entries)
          {'num': ++num, 'name': name, 'stream_id': id, 'category_id': '1'},
      ]),
      'get_vod_streams' => _json([
        for (final id in movies.keys) movie(id, ++num),
      ]),
      'get_series' => _json([for (final id in series.keys) show(id, ++num)]),
      _ => _json([
        for (final MapEntry(key: id, value: name) in categories.entries)
          {'category_id': id, 'category_name': name},
      ]),
    };
  }
}

void main() {
  group('empreintes brutes', () {
    test('le rang dans la liste ne change pas l empreinte', () {
      const before = '{"num":1,"name":"Dune","stream_id":10}';
      const after = '{"num":7,"name":"Dune","stream_id":10}';

      expect(rawEntryHash(before, 0), rawEntryHash(after, 0));
      expect(
        rawEntryHash('{"num":1,"name":"Dune 2","stream_id":10}', 0),
        isNot(rawEntryHash(before, 0)),
      );
      // Un groupe renommé change toutes ses entrées.
      expect(rawEntryHash(before, 1), isNot(rawEntryHash(before, 0)));
    });

    test('seuls les champs lus comptent', () {
      const fields = {'name', 'stream_id', 'stream_icon'};
      const before =
          '{"num":1,"name":"Dune","stream_id":10,"rating":"7.1",'
          '"stream_icon":"http://p/1.jpg","category_ids":[2,3]}';

      int hash(String raw) => rawFieldsHash(raw, fields, 0);
      // Une note recalculée, un rang ou une liste qui change : rien.
      expect(
        hash(
          '{"num":9,"name":"Dune","stream_id":10,"rating":"8.4",'
          '"stream_icon":"http://p/1.jpg","category_ids":[5]}',
        ),
        hash(before),
      );
      // Un champ lu qui change : l'objet change.
      expect(
        hash(before.replaceFirst('p/1.jpg', 'p/2.jpg')),
        isNot(hash(before)),
      );
      // Une virgule ou un guillemet échappé dans une valeur ne trompe pas
      // la lecture.
      expect(
        hash('{"plot":"Un, deux \\"trois\\"","name":"Dune","stream_id":10}'),
        hash('{"name":"Dune","plot":"autre","stream_id":10}'),
      );
      expect(rawFieldsHash(before, fields, 1), isNot(hash(before)));
    });

    test('lit l identifiant sans décoder l objet', () {
      expect(
        rawEntryId('{"num":1,"stream_id":123,"name":"x"}', 'stream_id'),
        123,
      );
      expect(rawEntryId('{"series_id": "45","name":"x"}', 'series_id'), 45);
      expect(rawEntryId('{"name":"x"}', 'stream_id'), isNull);
    });
  });

  group('synchronisation rapide', () {
    late AppDatabase db;
    late int sourceId;
    late _Panel panel;
    var now = DateTime.utc(2026, 11, 18, 8);

    Future<List<ImportProgress>> sync({bool full = false}) =>
        CatalogImportPipeline(
          database: db,
          catalogAdapter: XtreamSourceAdapter(
            MockClient((request) async => panel.answer(request)),
          ),
          epgAdapter: const FakeEpgAdapter(),
          clock: () => now,
          pause: (_) async {},
        ).run(sourceId, _xtream, full: full).toList();

    Future<int?> idOf(String table, String column, Object value) async {
      final row = await db
          .customSelect(
            'SELECT id FROM $table WHERE $column = ?1 AND catalog_id = '
            '(SELECT active_catalog_id FROM sources WHERE id = ?2)',
            variables: [Variable(value), Variable.withInt(sourceId)],
          )
          .getSingleOrNull();
      return row?.read<int>('id');
    }

    Future<List<String>> found(String query) async {
      final page = await SearchRepositoryImpl(
        db,
      ).search(sourceId, query, const PageRequest(), language: 'fr');
      return [for (final hit in page.items) hit.title];
    }

    /// Fiche du film [contentKey] dans le catalogue affiché.
    Future<String> sheetOf(String contentKey) async {
      final row = await db
          .customSelect(
            'SELECT grouping_key FROM movies WHERE content_key = ?1 AND '
            'catalog_id = (SELECT active_catalog_id FROM sources WHERE id = ?2)',
            variables: [
              Variable.withString(contentKey),
              Variable.withInt(sourceId),
            ],
          )
          .getSingle();
      return row.read<String>('grouping_key');
    }

    /// Deux films homonymes, puis une version traduite de chacun : l'une
    /// reconnue à son identifiant TMDb, l'autre à son affiche, que le
    /// panneau donne dans une autre taille.
    void addOdysseys({bool translations = true}) {
      panel
        ..movies[13] = "FR - L'Odyssée (2016)"
        ..movies[14] = "FR - L'Odyssée (2026)"
        ..movieTmdb.addAll({13: '331962', 14: '1368337'})
        ..moviePosters[14] = 'https://image.tmdb.org/t/p/w500/odyssee.jpg';
      if (!translations) return;
      panel
        ..movies[15] = 'EN - The Odyssey (2026)'
        ..movies[16] = "VOSTFR - L'Odyssée"
        ..movieTmdb[16] = '331962'
        ..moviePosters[15] = 'https://image.tmdb.org/t/p/original/odyssee.jpg';
    }

    Future<void> expectOdysseysGrouped() async {
      final classic = await sheetOf('x:m:13');
      final remake = await sheetOf('x:m:14');
      expect(classic, isNot(remake));
      // Sans année, la version rejoint le film de son identifiant TMDb.
      expect(await sheetOf('x:m:16'), classic);
      // Sous un autre titre, celui de son affiche.
      expect(await sheetOf('x:m:15'), remake);
      expect(await found('odyssée'), hasLength(2));
      expect(await found('odyssey'), hasLength(1));
    }

    setUp(() async {
      now = DateTime.utc(2026, 11, 18, 8);
      panel = _Panel();
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(setup: configureConnection),
          closeStreamsSynchronously: true,
        ),
      );
      final added = await PlaylistRepositoryImpl(
        db,
        MemoryCredentialStore(),
      ).add(name: 'Panneau', credentials: _xtream);
      sourceId = (added as Ok<PlaylistSource>).value.id;
      await sync();
      // Première synchronisation : les empreintes s'enregistrent.
      await sync();
    });

    tearDown(() => db.close());

    test('sans changement, rien n est réécrit, même pas les chaînes', () async {
      final tf1 = await idOf('live_channels', 'display_name', 'TF1');
      final dune = await idOf('movies', 'content_key', 'x:m:10');

      now = now.add(const Duration(days: 1));
      final progress = await sync();

      expect(await idOf('live_channels', 'display_name', 'TF1'), tf1);
      expect(await idOf('movies', 'content_key', 'x:m:10'), dune);
      expect(progress.last.merged, isTrue);
      // Chaque objet reçu compte dans l'avancement.
      expect(progress.last.processed, 5);
      final catalogs = await db.customSelect('SELECT id FROM catalogs').get();
      expect(catalogs, hasLength(1));
    });

    test('applique les ajouts, changements et retraits', () async {
      final dune = await idOf('movies', 'content_key', 'x:m:10');
      panel
        ..movies[10] = 'FR - Dune, deuxième partie'
        ..movies.remove(11)
        ..movies[12] = 'FR - Casablanca'
        ..channels[3] = 'FR: Arte';

      await sync();

      expect(await idOf('movies', 'content_key', 'x:m:10'), dune);
      expect(await idOf('movies', 'content_key', 'x:m:11'), isNull);
      expect(await idOf('movies', 'content_key', 'x:m:12'), isNotNull);
      expect(await found('casablanca'), ['Casablanca']);
      expect(await found('alien'), isEmpty);
      expect(await found('partie'), ['Dune, deuxième partie']);
      expect(await idOf('live_channels', 'display_name', 'Arte'), isNotNull);
      // Les chaînes changées sont réécrites en entier, une seule fois.
      final channels = await db
          .customSelect('SELECT COUNT(*) AS n FROM live_channels')
          .getSingle();
      expect(channels.read<int>('n'), 3);
    });

    test('une nouvelle version d une série rejoint les autres', () async {
      final lost = await idOf('series_entries', 'entry_key', 'x:s:20');
      panel.series[21] = ('EN - Lost', 100, '4607');

      await sync();

      final keys = await db
          .customSelect(
            'SELECT grouping_key FROM series_entries WHERE catalog_id = '
            '(SELECT active_catalog_id FROM sources WHERE id = ?1)',
            variables: [Variable.withInt(sourceId)],
          )
          .get();
      expect({
        for (final row in keys) row.read<String>('grouping_key'),
      }, hasLength(1));
      expect(await idOf('series_entries', 'entry_key', 'x:s:20'), lost);
      expect(await found('lost'), hasLength(1));
    });

    /// Marque le film [contentKey] : une synchronisation qui le traite
    /// rétablit son titre.
    Future<void> mark(String contentKey) => db.customStatement(
      "UPDATE movies SET display_title = 'MARQUE' WHERE content_key = ?1",
      [contentKey],
    );

    Future<String> titleOf(String contentKey) async =>
        (await db
                .customSelect(
                  'SELECT display_title FROM movies WHERE content_key = ?1',
                  variables: [Variable.withString(contentKey)],
                )
                .getSingle())
            .read<String>('display_title');

    test('une note recalculée partout ne fait rien retraiter', () async {
      await mark('x:m:10');
      panel.rating = '8.4';

      await sync();

      expect(await titleOf('x:m:10'), 'MARQUE');
    });

    test('le passage aux nouvelles empreintes ne retraite rien', () async {
      // L'état laissé par la 0.2 : empreintes de tout le texte, version 1.
      final groups = categoriesHash(_Panel.categories);
      String raw(Map<String, Object?> object) => jsonEncode(object);
      for (final id in panel.movies.keys) {
        await db.customStatement(
          'UPDATE movies SET source_hash = ?1 WHERE content_key = ?2',
          [rawEntryHash(raw(panel.movie(id, 1)), groups), 'x:m:$id'],
        );
      }
      for (final id in panel.series.keys) {
        await db.customStatement(
          'UPDATE series_entries SET source_hash = ?1 WHERE entry_key = ?2',
          [rawEntryHash(raw(panel.show(id, 1)), groups), 'x:s:$id'],
        );
      }
      await db.customStatement('UPDATE sources SET hash_version = 1');
      await mark('x:m:10');

      await sync();

      expect(await titleOf('x:m:10'), 'MARQUE');
      final version = await db
          .customSelect('SELECT hash_version AS v FROM sources')
          .getSingle();
      expect(version.read<int>('v'), entryHashVersion);
      // Les empreintes enregistrées sont désormais les nouvelles : une note
      // recalculée ne fait toujours rien retraiter.
      panel.rating = '8.4';
      await sync();
      expect(await titleOf('x:m:10'), 'MARQUE');
      // Un vrai changement, lui, passe.
      panel.movies[10] = 'FR - Dune, deuxième partie';
      await sync();
      expect(await titleOf('x:m:10'), 'Dune, deuxième partie');
    });

    test('un catalogue d avant les empreintes passe vite, sans rien '
        'perdre', () async {
      final dune = await idOf('movies', 'content_key', 'x:m:10');
      final lost = (await idOf('series_entries', 'entry_key', 'x:s:20'))!;
      // Le catalogue tel qu'une version précédente l'a laissé : sans
      // empreintes, avec une ligne de séparation.
      await db.customStatement('UPDATE movies SET source_hash = NULL');
      await db.customStatement('UPDATE series_entries SET source_hash = NULL');
      await db.customStatement('UPDATE sources SET live_hash = NULL');
      await db.customStatement(
        "INSERT INTO movies (catalog_id, raw_title, display_title, title_key, "
        "content_key, sort_order) SELECT active_catalog_id, '##### FILMS #####', "
        "'FILMS', 'films', 'x:m:99', 0 FROM sources",
      );
      panel.series[20] = ('FR - Lost', 200, '4607');

      await sync();

      expect(await idOf('movies', 'content_key', 'x:m:10'), dune);
      expect(await idOf('movies', 'content_key', 'x:m:99'), isNull);
      final unhashed = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM movies WHERE source_hash IS NULL',
          )
          .getSingle();
      expect(unhashed.read<int>('n'), 0);
      // Une série, elle, est traitée : sa modification n'est pas perdue.
      final row = await db.seriesEntryById(id: lost).getSingle();
      expect(row.lastModified, 200);
      expect(await found('dune'), ['Dune']);
    });

    test('un homonyme sépare les fiches, et les favoris et les reprises '
        'suivent', () async {
      panel
        ..movies[13] = "FR - L'Odyssée (2016)"
        ..movieTmdb[13] = '331962';
      await sync();
      final before = await sheetOf('x:m:13');
      await FavoritesRepositoryImpl(db).add(
        Favorite(
          sourceId: sourceId,
          kind: ContentKind.movie,
          key: before,
          title: "L'Odyssée",
          addedAt: now,
        ),
      );
      await db.customStatement(
        'INSERT INTO watch_progress (source_id, content_key, kind, title, '
        'position_ms, duration_ms, updated_at, work_key) '
        "VALUES (?1, 'x:m:13', 1, 'Odyssée', 1000, 2000, 0, ?2)",
        [sourceId, 'm:$before'],
      );
      addOdysseys(translations: false);
      // L'écran observe ses favoris : il doit voir le déplacement.
      final seen = <List<String>>[];
      final watching = FavoritesRepositoryImpl(db)
          .watch(sourceId)
          .listen((list) => seen.add([for (final f in list) f.key]));
      addTearDown(watching.cancel);

      await sync();
      await pumpEventQueue();

      final after = await sheetOf('x:m:13');
      expect(seen.last, [after]);
      expect(after, isNot(before));
      expect(after, isNot(await sheetOf('x:m:14')));
      final favorites = await db
          .customSelect('SELECT favorite_key, content_key FROM favorites')
          .get();
      expect(favorites.single.read<String>('favorite_key'), after);
      expect(favorites.single.read<String?>('content_key'), 'x:m:13');
      final progress = await db
          .customSelect('SELECT work_key FROM watch_progress')
          .getSingle();
      expect(progress.read<String?>('work_key'), 'm:$after');
    });

    test(
      'une version traduite ou sans année rejoint la fiche de son film',
      () async {
        addOdysseys(translations: false);
        await sync();
        addOdysseys();

        await sync();

        await expectOdysseysGrouped();
      },
    );

    test('un import complet regroupe les films de la même façon', () async {
      addOdysseys();

      await sync(full: true);

      await expectOdysseysGrouped();
    });

    test('une série modifiée sera redemandée', () async {
      final lost = (await idOf('series_entries', 'entry_key', 'x:s:20'))!;
      await db.saveSeriesDetails(
        id: lost,
        overview: 'Résumé',
        genre: null,
        runtimeMinutes: null,
      );
      panel.series[20] = ('FR - Lost', 200, '4607');

      await sync();

      final row = await db.seriesEntryById(id: lost).getSingle();
      expect(row.detailsLoaded, isFalse);
      expect(row.lastModified, 200);
    });
  });
}
