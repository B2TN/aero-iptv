import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart' hide AppDatabase;
import 'package:iptv_data/src/adapters/catalog_batch.dart';
import 'package:iptv_data/src/adapters/playlist_source_adapter.dart';
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

MovieEntry _movie(int id, String name) => MovieEntry(
  rawName: name,
  rawGroup: 'FILMS',
  locator: XtreamStream(
    namespace: XtreamNamespace.movie,
    streamId: id,
    extension: 'mkv',
  ),
);

SeriesEntry _series(int id, String name, {int? lastModified}) => SeriesEntry(
  rawName: name,
  rawGroup: 'SERIES',
  xtreamSeriesId: id,
  lastModified: lastModified,
);

LiveEntry _channel(int id, String name) => LiveEntry(
  rawName: name,
  rawGroup: 'FR | GENERAL',
  locator: XtreamStream(
    namespace: XtreamNamespace.live,
    streamId: id,
    extension: 'ts',
  ),
);

/// Une playlist Xtream : ses trois sections, livrées d'un seul essai.
SectionedCatalogAdapter _panel({
  required List<CatalogEntry> live,
  required List<CatalogEntry> movies,
  required List<CatalogEntry> series,
}) => SectionedCatalogAdapter({
  ContentKind.live: [succeeds(live)],
  ContentKind.movie: [succeeds(movies)],
  ContentKind.series: [succeeds(series)],
});

/// Réponse de `get_series_info` : les épisodes de la saison 1, par numéro.
String _seriesInfo(List<int> numbers) => jsonEncode({
  'info': {'plot': 'Des rescapés sur une île.'},
  'episodes': {
    '1': [
      for (final number in numbers)
        {
          'id': '${700 + number}',
          'season': 1,
          'episode_num': number,
          'title': 'Épisode $number',
          'container_extension': 'mkv',
        },
    ],
  },
});

void main() {
  late AppDatabase db;
  late MemoryCredentialStore vault;
  late int sourceId;
  var now = DateTime.utc(2026, 11, 17, 8);

  Future<List<ImportProgress>> sync(
    PlaylistSourceAdapter adapter, {
    bool full = false,
  }) => CatalogImportPipeline(
    database: db,
    catalogAdapter: adapter,
    epgAdapter: const FakeEpgAdapter(),
    clock: () => now,
    pause: (_) async {},
  ).run(sourceId, _xtream, full: full).toList();

  Future<int> activeCatalog() async =>
      (await db
              .customSelect(
                'SELECT active_catalog_id AS id FROM sources WHERE id = ?1',
                variables: [Variable.withInt(sourceId)],
              )
              .getSingle())
          .read<int>('id');

  /// Identifiant de la ligne de [table] dont la colonne [column] vaut [value],
  /// dans le catalogue affiché ; `null` si elle n'y est pas.
  Future<int?> idOf(String table, String column, Object value) async {
    final row = await db
        .customSelect(
          'SELECT id FROM $table WHERE catalog_id = ?1 AND $column = ?2',
          variables: [Variable.withInt(await activeCatalog()), Variable(value)],
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
    now = DateTime.utc(2026, 11, 17, 8);
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: configureConnection),
        closeStreamsSynchronously: true,
      ),
    );
    vault = MemoryCredentialStore();
    final added = await PlaylistRepositoryImpl(
      db,
      vault,
    ).add(name: 'Panneau', credentials: _xtream);
    sourceId = (added as Ok<PlaylistSource>).value.id;
  });

  tearDown(() => db.close());

  group('synchronisation différentielle', () {
    late int catalogId;
    late int dune;
    late int alien;
    late int lost;
    late int fringe;

    setUp(() async {
      await sync(
        _panel(
          live: [_channel(1, 'FR: TF1'), _channel(2, 'FR: France 2')],
          movies: [
            _movie(1, 'FR - Dune'),
            _movie(2, 'FR - Alien'),
            _movie(3, 'FR - Brazil'),
          ],
          series: [
            _series(9, 'FR - Lost', lastModified: 100),
            _series(10, 'FR - Fringe', lastModified: 100),
          ],
        ),
      );
      catalogId = await activeCatalog();
      dune = (await idOf('movies', 'content_key', 'x:m:1'))!;
      alien = (await idOf('movies', 'content_key', 'x:m:2'))!;
      lost = (await idOf('series_entries', 'entry_key', 'x:s:9'))!;
      fringe = (await idOf('series_entries', 'entry_key', 'x:s:10'))!;
      // Ce que l'utilisateur a ouvert depuis : un résumé, des épisodes.
      await db.saveMovieDetails(
        id: dune,
        overview: 'Une planète des sables.',
        genre: null,
        runtimeMinutes: null,
      );
      for (final entry in [lost, fringe]) {
        await db.saveSeriesDetails(
          id: entry,
          overview: 'Résumé',
          genre: null,
          runtimeMinutes: null,
        );
        await db.customStatement(
          'INSERT INTO episodes (catalog_id, series_entry_id, season, number, '
          "title, content_key, xtream_stream_id) VALUES (?1, ?2, 1, 1, 'Pilote', "
          "'x:e:' || ?2, ?2)",
          [catalogId, entry],
        );
      }

      now = DateTime.utc(2026, 11, 18, 8);
      await sync(
        _panel(
          live: [_channel(2, 'FR: France 2'), _channel(3, 'FR: Arte')],
          movies: [
            _movie(1, 'FR - Dune'),
            _movie(2, 'FR - Alien, le huitième passager'),
            _movie(4, 'FR - Casablanca'),
          ],
          series: [
            _series(9, 'FR - Lost', lastModified: 100),
            _series(10, 'FR - Fringe', lastModified: 200),
            _series(11, 'FR - Dark', lastModified: 100),
          ],
        ),
      );
    });

    test(
      'garde le catalogue affiché et efface celui qui vient d arriver',
      () async {
        expect(await activeCatalog(), catalogId);
        final catalogs = await db.customSelect('SELECT id FROM catalogs').get();
        expect(catalogs, hasLength(1));
        final source = await db
            .customSelect('SELECT last_synced_at AS at FROM sources')
            .getSingle();
        expect(source.read<int>('at'), now.millisecondsSinceEpoch);
      },
    );

    test('ajoute, met à jour et retire les films, sans changer leur '
        'identifiant', () async {
      expect(await idOf('movies', 'content_key', 'x:m:1'), dune);
      expect(await idOf('movies', 'content_key', 'x:m:2'), alien);
      expect(await idOf('movies', 'content_key', 'x:m:3'), isNull);
      expect(await idOf('movies', 'content_key', 'x:m:4'), isNotNull);

      final renamed = await db.movieById(id: alien).getSingle();
      expect(renamed.displayTitle, 'Alien, le huitième passager');
      // Le résumé chargé à l'ouverture reste.
      final kept = await db.movieById(id: dune).getSingle();
      expect(kept.overview, 'Une planète des sables.');
      expect(kept.detailsLoaded, isTrue);
    });

    test('tient la recherche à jour', () async {
      expect(await found('casablanca'), ['Casablanca']);
      expect(await found('brazil'), isEmpty);
      expect(await found('huitième'), ['Alien, le huitième passager']);
      expect(await found('dune'), ['Dune']);
      expect(await found('dark'), ['Dark']);
    });

    test(
      'une série modifiée sera redemandée, sans perdre ses épisodes',
      () async {
        final unchanged = await db.seriesEntryById(id: lost).getSingle();
        final modified = await db.seriesEntryById(id: fringe).getSingle();
        expect(unchanged.detailsLoaded, isTrue);
        expect(modified.detailsLoaded, isFalse);
        expect(modified.lastModified, 200);
        expect(await db.episodesForEntry(entryId: lost).get(), hasLength(1));
        expect(await db.episodesForEntry(entryId: fringe).get(), hasLength(1));
        expect(await idOf('series_entries', 'entry_key', 'x:s:11'), isNotNull);
      },
    );

    test('remplace les chaînes', () async {
      final names = await db
          .customSelect(
            'SELECT display_name FROM live_channels WHERE catalog_id = ?1 '
            'ORDER BY sort_order',
            variables: [Variable.withInt(catalogId)],
          )
          .get();
      expect(
        [for (final row in names) row.read<String>('display_name')],
        ['France 2', 'Arte'],
      );
    });
  });

  test('un import complet remplace le catalogue', () async {
    final panel = _panel(
      live: [_channel(1, 'FR: TF1')],
      movies: [_movie(1, 'FR - Dune')],
      series: [_series(9, 'FR - Lost')],
    );
    await sync(panel);
    final first = await activeCatalog();

    await sync(panel, full: true);

    expect(await activeCatalog(), isNot(first));
    expect(await found('dune'), ['Dune']);
  });

  test('une section en panne garde son contenu, les autres avancent', () async {
    await sync(
      _panel(
        live: [_channel(1, 'FR: TF1')],
        movies: [_movie(1, 'FR - Dune')],
        series: [_series(9, 'FR - Lost')],
      ),
    );

    await sync(
      SectionedCatalogAdapter({
        ContentKind.live: [
          succeeds([_channel(1, 'FR: TF1')]),
        ],
        ContentKind.movie: [fails(const NetworkFailure('coupure'))],
        ContentKind.series: [
          succeeds([_series(11, 'FR - Dark')]),
        ],
      }),
    );

    expect(await idOf('movies', 'content_key', 'x:m:1'), isNotNull);
    expect(await idOf('series_entries', 'entry_key', 'x:s:9'), isNull);
    expect(await idOf('series_entries', 'entry_key', 'x:s:11'), isNotNull);
  });

  test('une playlist M3U ajoute et retire ses épisodes', () async {
    EpisodeEntry episode(int number) => EpisodeEntry(
      rawName: 'FR - Lost S01E0$number',
      rawGroup: 'SERIES',
      locator: DirectStream('http://s/lost/$number.mkv'),
    );
    await sync(
      FakeCatalogAdapter([
        CatalogBatch([episode(1), episode(2)]),
      ]),
    );
    final second = await idOf(
      'episodes',
      'content_key',
      'm:e:FR - Lost S01E02',
    );

    await sync(
      FakeCatalogAdapter([
        CatalogBatch([episode(2), episode(3)]),
      ]),
    );

    expect(
      await idOf('episodes', 'content_key', 'm:e:FR - Lost S01E01'),
      isNull,
    );
    expect(
      await idOf('episodes', 'content_key', 'm:e:FR - Lost S01E02'),
      second,
    );
    final third = await idOf('episodes', 'content_key', 'm:e:FR - Lost S01E03');
    expect(third, isNotNull);
    final row = await db
        .customSelect(
          'SELECT series_entry_id AS entry FROM episodes WHERE id = ?1',
          variables: [Variable.withInt(third!)],
        )
        .getSingle();
    expect(
      row.read<int>('entry'),
      await idOf('episodes', 'content_key', 'm:e:FR - Lost S01E02').then(
        (id) async =>
            (await db
                    .customSelect(
                      'SELECT series_entry_id AS entry FROM episodes WHERE id = ?1',
                      variables: [Variable.withInt(id!)],
                    )
                    .getSingle())
                .read<int>('entry'),
      ),
    );
  });

  test(
    'une série modifiée reçoit ses nouveaux épisodes à l ouverture',
    () async {
      var numbers = [1];
      vault.values[sourceId] = _xtream;
      final repository = CatalogRepositoryImpl(
        db,
        vault,
        MockClient((_) async => http.Response(_seriesInfo(numbers), 200)),
      );
      await sync(
        _panel(
          live: [_channel(1, 'FR: TF1')],
          movies: [_movie(1, 'FR - Dune')],
          series: [_series(9, 'FR - Lost', lastModified: 100)],
        ),
      );
      final lost = (await idOf('series_entries', 'entry_key', 'x:s:9'))!;
      final before = await repository.seasonsOf(sourceId, lost);
      final pilot = before.single.episodes.single;

      numbers = [1, 2];
      await sync(
        _panel(
          live: [_channel(1, 'FR: TF1')],
          movies: [_movie(1, 'FR - Dune')],
          series: [_series(9, 'FR - Lost', lastModified: 200)],
        ),
      );
      final after = await repository.seasonsOf(sourceId, lost);

      expect([for (final e in after.single.episodes) e.number], [1, 2]);
      // L'épisode déjà connu garde sa ligne.
      expect(after.single.episodes.first.id, pilot.id);
    },
  );
}
