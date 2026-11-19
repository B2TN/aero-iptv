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

  /// Séries : nom, date de modification, identifiant TMDb.
  final Map<int, (String, int, String)> series = {
    20: ('FR - Lost', 100, '4607'),
  };
  final List<String> asked = [];

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
        for (final MapEntry(key: id, value: name) in movies.entries)
          {
            'num': ++num,
            'name': name,
            'stream_id': id,
            'category_id': '2',
            'container_extension': 'mkv',
          },
      ]),
      'get_series' => _json([
        for (final MapEntry(key: id, value: (name, modified, tmdb))
            in series.entries)
          {
            'num': ++num,
            'name': name,
            'series_id': id,
            'category_id': '3',
            'last_modified': '$modified',
            'tmdb': tmdb,
          },
      ]),
      _ => _json([
        {'category_id': '1', 'category_name': 'FR| TNT'},
        {'category_id': '2', 'category_name': 'FILMS'},
        {'category_id': '3', 'category_name': 'SERIES'},
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
