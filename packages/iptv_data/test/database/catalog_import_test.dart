import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart' hide AppDatabase;
import 'package:iptv_data/src/adapters/catalog_batch.dart';
import 'package:iptv_data/src/adapters/m3u/m3u_source_adapter.dart';
import 'package:iptv_data/src/adapters/playlist_source_adapter.dart';
import 'package:iptv_data/src/database/app_database.dart'
    hide AppSettings, WatchProgress;
import 'package:iptv_data/src/epg/epg_source_adapter.dart';
import 'package:iptv_data/src/import/catalog_import_pipeline.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

const m3u = M3uCredentials(playlistUrl: 'http://s.example/list.m3u');
final DateTime now = DateTime.utc(2026, 10, 31, 20);

void main() {
  late AppDatabase db;
  late MemoryCredentialStore vault;
  late PlaylistRepositoryImpl playlists;
  late LiveTvRepositoryImpl liveTv;
  late CatalogRepositoryImpl catalog;
  late SearchRepositoryImpl search;
  late EpgRepositoryImpl epg;
  late int sourceId;

  /// Attentes demandées entre deux essais : aucune n'est réellement observée.
  final pauses = <Duration>[];

  Future<List<ImportProgress>> runImport(
    PlaylistSourceAdapter adapter, {
    EpgSourceAdapter epgAdapter = const FakeEpgAdapter(),
  }) => CatalogImportPipeline(
    database: db,
    catalogAdapter: adapter,
    epgAdapter: epgAdapter,
    clock: () => now,
    pause: (duration) async => pauses.add(duration),
  ).run(sourceId, m3u).toList();

  Future<void> importFixture() async {
    final body = File('test/fixtures/sample.m3u').readAsStringSync();
    final client = MockClient(
      (_) async => http.Response.bytes(utf8.encode(body), 200),
    );
    await runImport(M3uSourceAdapter(client));
  }

  /// Ajoute une version de série au catalogue actif, et à l'index de recherche.
  Future<void> addSeriesVersion(
    String title, {
    required String key,
    required String tag,
    String? poster,
  }) async {
    await db.customStatement(
      '''
      INSERT INTO series_entries (catalog_id, raw_title, display_title,
        title_key, grouping_key, language_tag, poster_url, sort_order)
      SELECT active_catalog_id, ?1, ?1, ?2, ?3, ?4, ?5, 900
      FROM sources WHERE id = ?6
      ''',
      [title, GroupingKey.of(title), key, tag, poster, sourceId],
    );
    await db.customStatement(
      '''
      INSERT INTO search_index (title, group_key, kind, ref_id, catalog_id,
        poster_url)
      SELECT display_title, 's' || grouping_key, 2, id, catalog_id, poster_url
      FROM series_entries WHERE raw_title = ?1
      ''',
      [title],
    );
  }

  /// Ajoute une version de film au catalogue actif, et à l'index de recherche.
  Future<void> addMovieVersion(
    String title, {
    required String tag,
    String? poster,
    String? displayTitle,
  }) async {
    await db.customStatement(
      '''
      INSERT INTO movies (catalog_id, raw_title, display_title, title_key,
        content_key, language_tag, poster_url, stream_url, sort_order)
      SELECT active_catalog_id, ?1 || ?2, ?1, ?3, ?1 || ?2, ?2, ?4,
        'http://s/film.mkv', 900
      FROM sources WHERE id = ?5
      ''',
      [displayTitle ?? title, tag, GroupingKey.of(title), poster, sourceId],
    );
    await db.customStatement(
      '''
      INSERT INTO search_index (title, group_key, kind, ref_id, catalog_id,
        poster_url)
      SELECT display_title, 'm' || title_key, 1, id, catalog_id, poster_url
      FROM movies WHERE raw_title = ?1 || ?2
      ''',
      [displayTitle ?? title, tag],
    );
  }

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  setUp(() async {
    pauses.clear();
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: configureConnection),
        closeStreamsSynchronously: true,
      ),
    );
    vault = MemoryCredentialStore();
    playlists = PlaylistRepositoryImpl(db, vault);
    liveTv = LiveTvRepositoryImpl(db);
    catalog = CatalogRepositoryImpl(db, vault, http.Client());
    search = SearchRepositoryImpl(db);
    epg = EpgRepositoryImpl(db);
    final added = await playlists.add(name: 'Test', credentials: m3u);
    sourceId = (added as Ok<PlaylistSource>).value.id;
  });

  tearDown(() => db.close());

  group('Live TV', () {
    setUp(importFixture);

    test('liste les pays présents', () async {
      final countries = await liveTv.countries(sourceId);
      expect(countries.map((c) => c.code), containsAll(['FR', 'GB']));
    });

    test('fusionne les groupes et les qualités', () async {
      final groups = await liveTv.groups(sourceId, 'FR', grouped: true);
      expect(groups, hasLength(1));
      expect(groups.single.displayName, isEmpty);

      final page = await liveTv.channels(
        sourceId,
        'FR',
        groups.single,
        const PageRequest(),
        grouped: true,
      );
      final channel = page.items.single;
      expect(channel.name, 'TF1');
      expect(channel.logoUrl, 'http://logo.example/tf1.png');
      expect(channel.epgKey, 'tf1.fr');

      final streams = await liveTv.streamsOf(sourceId, channel, grouped: true);
      expect(streams.map((s) => s.quality), [
        StreamQuality.fhd,
        StreamQuality.hd,
        StreamQuality.sd,
      ]);
    });

    test('rétablit la vue brute sans réimport', () async {
      final groups = await liveTv.groups(sourceId, 'FR', grouped: false);
      expect(groups.map((g) => g.displayName), [
        'FRANCE FHD',
        'FRANCE HD',
        'FRANCE SD',
      ]);

      final page = await liveTv.channels(
        sourceId,
        'FR',
        groups.first,
        const PageRequest(),
        grouped: false,
      );
      final channel = page.items.single;
      expect(channel.name, 'FR: TF1 FHD');
      final streams = await liveTv.streamsOf(sourceId, channel, grouped: false);
      expect(streams, hasLength(1));
    });

    test('écarte les lignes de séparation', () async {
      expect(await count('live_channels'), 4);
    });

    test('pagine les chaînes', () async {
      await runImport(
        FakeCatalogAdapter([
          CatalogBatch([
            for (var i = 0; i < 5; i++) live('Chaîne $i', 'FRANCE', id: i),
          ]),
        ]),
      );
      final group = (await liveTv.groups(sourceId, 'FR', grouped: true)).single;
      final first = await liveTv.channels(
        sourceId,
        'FR',
        group,
        const PageRequest(limit: 2),
        grouped: true,
      );
      expect(first.items.map((c) => c.name), ['Chaîne 0', 'Chaîne 1']);
      expect(first.hasMore, isTrue);

      final last = await liveTv.channels(
        sourceId,
        'FR',
        group,
        const PageRequest(limit: 2, offset: 4),
        grouped: true,
      );
      expect(last.items.map((c) => c.name), ['Chaîne 4']);
      expect(last.hasMore, isFalse);
    });
  });

  group('Séries', () {
    setUp(importFixture);

    test('fusionne les versions multi-langues', () async {
      final page = await catalog.series(
        sourceId,
        const PageRequest(),
        grouped: true,
        language: 'fr',
      );
      final breakingBad = page.items.firstWhere(
        (s) => s.title == 'Breaking Bad',
      );
      expect(breakingBad.versionCount, 2);

      final versions = await catalog.versionsOf(
        sourceId,
        breakingBad.groupingKey,
      );
      expect(versions.map((v) => v.label), containsAll(['FR', 'EN']));
    });

    group('langue de l application', () {
      const key = 'coeursnoirs';

      setUp(() async {
        await addSeriesVersion(
          'Dark Hearts',
          key: key,
          tag: 'EN',
          poster: 'http://p/en.jpg',
        );
        await addSeriesVersion(
          'Cœurs Noirs',
          key: key,
          tag: 'FR',
          poster: 'http://p/fr.jpg',
        );
        await addSeriesVersion('Fuerzas especiales', key: key, tag: 'ES');
      });

      Future<Series> show(String language) async {
        final page = await catalog.series(
          sourceId,
          const PageRequest(),
          grouped: true,
          language: language,
        );
        return page.items.firstWhere((s) => s.groupingKey == key);
      }

      test('montre le titre et l affiche de la bonne version', () async {
        final french = await show('fr');
        expect(french.title, 'Cœurs Noirs');
        expect(french.posterUrl, 'http://p/fr.jpg');
        expect(french.versionCount, 3);

        final english = await show('en');
        expect(english.title, 'Dark Hearts');
        expect(english.posterUrl, 'http://p/en.jpg');
      });

      test('se rabat sur l anglais si la langue manque', () async {
        expect((await show('de')).title, 'Dark Hearts');
      });

      test('emprunte une affiche si la bonne version n en a pas', () async {
        final spanish = await show('es');
        expect(spanish.title, 'Fuerzas especiales');
        expect(spanish.posterUrl, isNotNull);
      });

      test('retrouve une série par n importe lequel de ses titres', () async {
        final found = await catalog.seriesByTitleKeys(
          sourceId,
          {'darkhearts'},
          grouped: true,
          language: 'fr',
        );
        expect(found['darkhearts']?.title, 'Cœurs Noirs');
        expect(found['darkhearts']?.versionCount, 3);
      });

      test('la recherche montre aussi la bonne version', () async {
        final page = await search.search(
          sourceId,
          'fuerzas',
          const PageRequest(),
          language: 'fr',
        );
        expect(page.items.single.title, 'Cœurs Noirs');
        expect(page.items.single.posterUrl, 'http://p/fr.jpg');

        final series = await catalog.seriesById(page.items.single.id);
        expect(series?.groupingKey, key);
        expect(series?.title, 'Cœurs Noirs');
      });
    });

    test('sépare deux séries homonymes grâce à l année', () async {
      final page = await catalog.series(
        sourceId,
        const PageRequest(),
        grouped: true,
        language: 'fr',
      );
      final flashes = page.items.where((s) => s.title == 'The Flash').toList();
      expect(flashes, hasLength(2));
      expect(flashes.map((s) => s.versionCount), [1, 1]);
    });

    test('expose la vue brute si la fusion est désactivée', () async {
      final page = await catalog.series(
        sourceId,
        const PageRequest(),
        grouped: false,
        language: 'fr',
      );
      expect(page.items.map((s) => s.title), contains('FR - Breaking Bad'));
      expect(page.items.map((s) => s.title), contains('EN - Breaking Bad'));
    });

    test('range les épisodes par saison', () async {
      final page = await catalog.series(
        sourceId,
        const PageRequest(),
        grouped: true,
        language: 'fr',
      );
      final breakingBad = page.items.firstWhere(
        (s) => s.title == 'Breaking Bad',
      );
      final versions = await catalog.versionsOf(
        sourceId,
        breakingBad.groupingKey,
      );
      final french = versions.firstWhere((v) => v.label == 'FR');

      final seasons = await catalog.seasonsOf(sourceId, french.seriesEntryId);
      expect(seasons.single.number, 1);
      expect(seasons.single.episodes.map((e) => e.number), [1, 2]);
    });
  });

  group('séries Xtream', () {
    test('charge les épisodes à la première ouverture seulement', () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.url.queryParameters['action'], 'get_series_info');
        return http.Response(
          jsonEncode({
            'episodes': {
              '1': [
                {
                  'id': '77',
                  'season': 1,
                  'episode_num': 1,
                  'title': 'Pilote',
                  'container_extension': 'mkv',
                },
              ],
            },
          }),
          200,
        );
      });
      vault.values[sourceId] = const XtreamCredentials(
        serverUrl: 'http://s.example',
        username: 'u',
        password: 'p',
      );
      await runImport(
        const FakeCatalogAdapter([
          CatalogBatch([
            SeriesEntry(
              rawName: 'FR - Lost',
              rawGroup: 'SERIES',
              xtreamSeriesId: 9,
            ),
          ]),
        ]),
      );
      final repository = CatalogRepositoryImpl(db, vault, client);
      final page = await repository.series(
        sourceId,
        const PageRequest(),
        grouped: true,
        language: 'fr',
      );

      final first = await repository.seasonsOf(sourceId, page.items.single.id);
      final second = await repository.seasonsOf(sourceId, page.items.single.id);

      final episode = first.single.episodes.single;
      expect(episode.contentKey, 'x:e:77');
      expect(
        (episode.locator as XtreamStream).namespace,
        XtreamNamespace.series,
      );
      expect(second.single.episodes, hasLength(1));
      expect(requests, 1);
    });
  });

  group('recherche', () {
    setUp(importFixture);

    test('trouve un film par préfixe', () async {
      final page = await search.search(
        sourceId,
        'inc',
        const PageRequest(),
        language: 'fr',
      );
      expect(page.items.single.title, 'Inception');
      expect(page.items.single.kind, ContentKind.movie);
    });

    test('ignore les accents et la casse', () async {
      final page = await search.search(
        sourceId,
        'BRÉAKING',
        const PageRequest(),
        language: 'fr',
      );
      expect(page.items.single.title, 'Breaking Bad');
    });

    test('ne renvoie qu un résultat par série fusionnée', () async {
      final page = await search.search(
        sourceId,
        'break',
        const PageRequest(),
        language: 'fr',
      );
      expect(page.items, hasLength(1));
      expect(page.items.single.kind, ContentKind.series);
    });

    test('propose des suggestions', () async {
      expect(await search.suggest(sourceId, 'bre'), ['Breaking Bad']);
    });

    test('ne renvoie qu un résultat par film, dans la bonne langue', () async {
      await addMovieVersion('Inception', tag: 'EN', poster: 'http://p/en.jpg');
      await addMovieVersion(
        'Inception',
        tag: 'DE',
        poster: 'http://p/de.jpg',
        displayTitle: 'Inception (Deutsch)',
      );

      final page = await search.search(
        sourceId,
        'inc',
        const PageRequest(),
        language: 'de',
      );

      expect(page.items.single.title, 'Inception (Deutsch)');
      expect(page.items.single.posterUrl, 'http://p/de.jpg');
    });

    test('sans regroupement, montre chaque version avec sa langue', () async {
      await addMovieVersion('Inception', tag: 'EN', poster: 'http://p/en.jpg');
      await addMovieVersion('Inception', tag: 'DE', poster: 'http://p/de.jpg');

      final grouped = await search.search(
        sourceId,
        'inception',
        const PageRequest(),
        language: 'fr',
      );
      final page = await search.search(
        sourceId,
        'inception',
        const PageRequest(),
        language: 'fr',
        groupMovies: false,
      );

      // La playlist de test a déjà son Inception : trois versions en tout.
      expect(grouped.items, hasLength(1));
      final titles = [for (final hit in page.items) hit.title];
      expect(titles, hasLength(3));
      expect(titles, containsAll(['Inception (EN)', 'Inception (DE)']));
      expect(
        {for (final hit in page.items) hit.id}.length,
        page.items.length,
        reason: 'chaque version garde son propre identifiant',
      );
    });

    test('sans regroupement, les séries restent groupées', () async {
      final grouped = await search.search(
        sourceId,
        'break',
        const PageRequest(),
        language: 'fr',
      );
      final ungrouped = await search.search(
        sourceId,
        'break',
        const PageRequest(),
        language: 'fr',
        groupMovies: false,
      );

      List<String> seriesOf(Page<SearchHit> page) => [
        for (final hit in page.items)
          if (hit.kind == ContentKind.series) hit.title,
      ];
      expect(seriesOf(grouped), ['Breaking Bad']);
      expect(seriesOf(ungrouped), seriesOf(grouped));
    });

    test('liste les films d une langue', () async {
      await addMovieVersion('Dune', tag: 'EN');
      await addMovieVersion('Dune', tag: 'AR');
      await addMovieVersion('Inception', tag: 'ARA');

      final movies = await catalog.moviesInLanguage(
        sourceId,
        'ar',
        const PageRequest(),
      );

      expect(movies.map((movie) => movie.languageTag), ['AR', 'ARA']);
    });

    test('résiste aux caractères réservés de FTS5', () async {
      final page = await search.search(
        sourceId,
        '"inc*- OR',
        const PageRequest(),
        language: 'fr',
      );
      expect(page.items, isEmpty);
      expect(await search.suggest(sourceId, '*-'), isEmpty);
    });
  });

  group('guide', () {
    test('retourne l émission en cours et purge le passé', () async {
      final adapter = FakeEpgAdapter(
        programmes: [
          EpgProgramme(
            epgKey: 'tf1',
            title: 'En cours',
            start: now.subtract(const Duration(minutes: 30)),
            stop: now.add(const Duration(minutes: 30)),
          ),
          EpgProgramme(
            epgKey: 'tf1',
            title: 'Ensuite',
            start: now.add(const Duration(minutes: 30)),
            stop: now.add(const Duration(minutes: 90)),
          ),
          EpgProgramme(
            epgKey: 'tf1',
            title: 'Ancienne',
            start: now.subtract(const Duration(hours: 9)),
            stop: now.subtract(const Duration(hours: 8)),
          ),
        ],
      );
      await runImport(
        FakeCatalogAdapter([
          CatalogBatch([live('TF1', 'FRANCE')]),
        ]),
        epgAdapter: adapter,
      );

      final playing = await epg.nowPlaying(sourceId, ['tf1', 'absente'], now);
      expect(playing.keys, ['tf1']);
      expect(playing['tf1']!.title, 'En cours');
      expect(await count('epg_programmes'), 2);
    });

    test('un guide en erreur ne bloque pas le catalogue', () async {
      final events = await runImport(
        FakeCatalogAdapter([
          CatalogBatch([live('TF1', 'FRANCE')]),
        ]),
        epgAdapter: const FakeEpgAdapter(failure: NetworkFailure('hors ligne')),
      );
      expect(events.last.stage, ImportStage.done);
      expect(events.last.epgFailed, isTrue);
      expect(await liveTv.countries(sourceId), isNotEmpty);
    });
  });

  group('bascule du catalogue', () {
    test('remplace l ancien catalogue et le supprime', () async {
      await importFixture();
      await runImport(
        FakeCatalogAdapter([
          CatalogBatch([live('M6', 'FRANCE')]),
        ]),
      );
      final group = (await liveTv.groups(sourceId, 'FR', grouped: true)).single;
      final page = await liveTv.channels(
        sourceId,
        'FR',
        group,
        const PageRequest(),
        grouped: true,
      );
      expect(page.items.single.name, 'M6');
      expect(await count('live_channels'), 1);
      expect(await count('movies'), 0);
      expect(await count('search_index'), 0);
      expect(await count('catalogs'), 1);
    });

    test('garde l ancien catalogue si l import échoue', () async {
      await importFixture();
      final attempt = runImport(
        FakeCatalogAdapter([
          CatalogBatch([live('Partiel', 'FRANCE')]),
        ], failure: const NetworkFailure('coupure')),
      );
      await expectLater(attempt, throwsA(isA<NetworkFailure>()));

      final group = (await liveTv.groups(sourceId, 'FR', grouped: true)).single;
      final page = await liveTv.channels(
        sourceId,
        'FR',
        group,
        const PageRequest(),
        grouped: true,
      );
      expect(page.items.single.name, 'TF1');
      expect(await count('live_channels'), 4);
      expect(await count('catalogs'), 1);
    });

    test('refuse une source vide sans toucher au catalogue', () async {
      await importFixture();
      await expectLater(
        runImport(const FakeCatalogAdapter([])),
        throwsA(isA<ParseFailure>()),
      );
      expect(await count('live_channels'), 4);
    });

    test('supprime les restes d un import interrompu', () async {
      await importFixture();
      final orphan = await db
          .into(db.catalogs)
          .insert(CatalogsCompanion.insert(sourceId: sourceId, createdAt: 0));
      await db
          .into(db.channelGroups)
          .insert(
            ChannelGroupsCompanion.insert(
              catalogId: orphan,
              rawName: 'orphelin',
              displayName: '',
              groupingKey: '',
              sortOrder: 0,
            ),
          );
      await importFixture();
      expect(await count('catalogs'), 1);
    });
  });

  group('finitions', () {
    /// Toute modification d'une série échoue, en erreur SQLite 1 : la base
    /// refuse une étape de la préparation du catalogue.
    Future<void> breakSeriesUpdates() => db.customStatement(
      'CREATE TRIGGER casse BEFORE UPDATE ON series_entries '
      'BEGIN INSERT INTO absente VALUES (1); END',
    );

    Future<List<ImportProgress>> importSample() {
      final body = File('test/fixtures/sample.m3u').readAsStringSync();
      final client = MockClient(
        (_) async => http.Response.bytes(utf8.encode(body), 200),
      );
      return runImport(M3uSourceAdapter(client));
    }

    test(
      'une finition refusée n empêche pas d afficher le catalogue',
      () async {
        await breakSeriesUpdates();

        final progress = await importSample();

        final done = progress.last;
        expect(done.stage, ImportStage.done);
        // Seule la séparation des homonymes modifie des séries de cet exemple.
        expect(done.failedRefinements.keys, [CatalogRefinement.homonyms]);
        final failure =
            done.failedRefinements[CatalogRefinement.homonyms]!
                as StorageFailure;
        expect(failure.code, 1);
        expect(failure.detail, contains('no such table'));
        expect(failure.detail, contains('SQLite 3.'));

        final movies = await catalog.movies(sourceId, const PageRequest());
        expect(movies.items, isNotEmpty);
        final found = await search.search(
          sourceId,
          'inc',
          const PageRequest(),
          language: 'fr',
        );
        expect(found.items.single.title, 'Inception');
      },
    );

    test('un import sans incident ne signale aucune finition', () async {
      final progress = await importSample();

      expect(progress.last.failedRefinements, isEmpty);
    });
  });

  group('sections', () {
    const outage = ServerFailure('panne', status: 503);

    test('une section en échec ne fait pas perdre les autres', () async {
      final adapter = SectionedCatalogAdapter({
        ContentKind.live: [fails(outage)],
        ContentKind.movie: [
          succeeds([movie('Lagon (2020)')]),
        ],
      });

      final progress = await runImport(adapter);

      expect(await count('movies'), 1);
      expect(await count('live_channels'), 0);
      expect(progress.last.stage, ImportStage.done);
      expect(progress.last.failedSections.keys, [ContentKind.live]);
      expect(progress.last.failedSections[ContentKind.live], outage);
      expect(
        (await catalog.movies(
          sourceId,
          const PageRequest(),
        )).items.single.title,
        'Lagon',
      );
    });

    test('une erreur imprévue ne coûte pas les autres sections', () async {
      final adapter = SectionedCatalogAdapter({
        ContentKind.series: [fails(StateError('défaut'))],
        ContentKind.movie: [
          succeeds([movie('Lagon (2020)')]),
        ],
      });

      final progress = await runImport(adapter);

      expect(await count('movies'), 1);
      expect(progress.last.stage, ImportStage.done);
      final failure = progress.last.failedSections[ContentKind.series];
      expect(failure, isA<UnexpectedFailure>());
      expect((failure! as UnexpectedFailure).kind, 'StateError');
      // Un défaut de l'application ne se répare pas en réessayant.
      expect(adapter.calls[ContentKind.series], 1);
    });

    test('reprend une section après une panne passagère', () async {
      final adapter = SectionedCatalogAdapter({
        ContentKind.live: [
          fails(
            const NetworkFailure('coupure'),
            after: [live('TF1', 'FRANCE')],
          ),
          succeeds([live('TF1', 'FRANCE'), live('M6', 'FRANCE', id: 2)]),
        ],
      });

      final progress = await runImport(adapter);

      // Ni chaîne ni groupe en double : le premier essai a été effacé.
      expect(await count('live_channels'), 2);
      expect(await count('channel_groups'), 1);
      expect(adapter.calls[ContentKind.live], 2);
      expect(pauses, [const Duration(seconds: 4)]);
      expect(progress.last.failedSections, isEmpty);
    });

    test('abandonne une section après trois essais', () async {
      final adapter = SectionedCatalogAdapter({
        ContentKind.live: [fails(outage)],
        ContentKind.movie: [
          succeeds([movie('Lagon (2020)')]),
        ],
      });

      await runImport(adapter);

      expect(adapter.calls[ContentKind.live], 3);
      expect(pauses, [const Duration(seconds: 4), const Duration(seconds: 8)]);
    });

    test('ne réessaie pas un refus du compte', () async {
      final adapter = SectionedCatalogAdapter({
        ContentKind.live: [fails(const AuthFailure('refus', status: 403))],
        ContentKind.movie: [
          succeeds([movie('Lagon (2020)')]),
        ],
      });

      final progress = await runImport(adapter);

      expect(adapter.calls[ContentKind.live], 1);
      expect(pauses, isEmpty);
      expect(progress.last.failedSections.keys, [ContentKind.live]);
    });

    test('une section en échec garde son contenu précédent', () async {
      await importFixture();
      final channels = await count('live_channels');
      final groups = await count('channel_groups');
      expect(channels, greaterThan(0));

      await runImport(
        SectionedCatalogAdapter({
          ContentKind.live: [fails(outage)],
          ContentKind.movie: [
            succeeds([movie('Lagon (2020)')]),
          ],
        }),
      );

      expect(await count('live_channels'), channels);
      expect(await count('channel_groups'), groups);
      expect(await count('movies'), 1);
      expect(await count('catalogs'), 1);
      final group = (await liveTv.groups(sourceId, 'FR', grouped: true)).first;
      final page = await liveTv.channels(
        sourceId,
        'FR',
        group,
        const PageRequest(),
        grouped: true,
      );
      expect(page.items, isNotEmpty);
    });

    test('si tout échoue, l ancien catalogue reste en place', () async {
      await importFixture();
      final channels = await count('live_channels');

      await expectLater(
        runImport(
          SectionedCatalogAdapter({
            ContentKind.live: [fails(outage)],
            ContentKind.movie: [fails(const NetworkFailure('coupure'))],
          }),
        ),
        throwsA(same(outage)),
      );

      expect(await count('live_channels'), channels);
      expect(await count('catalogs'), 1);
    });

    test('annonce la section en cours, puis le guide', () async {
      final progress = await runImport(
        SectionedCatalogAdapter({
          ContentKind.live: [
            succeeds([live('TF1', 'FRANCE')]),
          ],
          ContentKind.movie: [
            succeeds([movie('Lagon (2020)')]),
          ],
        }),
      );

      expect(
        [
          for (final step in progress)
            if (step.stage == ImportStage.catalog)
              (step.section, step.processed),
        ],
        [(ContentKind.live, 1), (ContentKind.movie, 2)],
      );
      expect(progress.map((step) => step.stage), [
        ImportStage.connecting,
        ImportStage.catalog,
        ImportStage.catalog,
        ImportStage.indexing,
        ImportStage.epg,
        ImportStage.done,
      ]);
    });

    test('une source d un seul tenant est aussi reprise', () async {
      await expectLater(
        runImport(
          FakeCatalogAdapter([
            CatalogBatch([live('Partiel', 'FRANCE')]),
          ], failure: const NetworkFailure('coupure')),
        ),
        throwsA(isA<NetworkFailure>()),
      );

      expect(pauses, hasLength(2));
      expect(await count('live_channels'), 0);
      expect(await count('catalogs'), 0);
    });
  });

  group('sources', () {
    test('supprimer une source efface tout', () async {
      await importFixture();
      final result = await playlists.delete(sourceId);
      expect(result, isA<Ok<void>>());
      expect(await count('sources'), 0);
      expect(await count('catalogs'), 0);
      expect(await count('live_channels'), 0);
      expect(await count('search_index'), 0);
      expect(vault.values, isEmpty);
    });

    test('garde les identifiants hors de SQLite', () async {
      final row = await db
          .customSelect(
            'SELECT * FROM sources WHERE id = ?',
            variables: [Variable.withInt(sourceId)],
          )
          .getSingle();
      expect(row.data.values.join(), isNot(contains('list.m3u')));
      expect(vault.values[sourceId], isNotNull);
    });

    test('signale une source disparue', () async {
      final result = await playlists.update(
        const PlaylistSource(id: 999, name: 'x', kind: SourceKind.m3u),
      );
      expect(result, isA<Err<void>>());
    });
  });

  group('réglages et progression', () {
    test('applique les valeurs par défaut puis persiste', () async {
      final settings = SettingsRepositoryImpl(db);
      final initial = await settings.watch().first;
      expect(initial.groupSeries, isTrue);

      await settings.save(
        initial.copyWith(
          groupSeries: false,
          liveDelaySeconds: 5,
          catalogRules: 3,
        ),
      );
      final updated = await settings.watch().first;
      expect(updated.groupSeries, isFalse);
      expect(updated.liveDelaySeconds, 5);
      expect(updated.catalogRules, 3);
      expect(updated.groupChannels, isTrue);
    });

    test('garde l apparence des sous-titres', () async {
      final settings = SettingsRepositoryImpl(db);
      expect(
        (await settings.watch().first).subtitleStyle,
        const SubtitleStyle(),
      );
      const style = SubtitleStyle(
        size: SubtitleSize.large,
        font: SubtitleFont.serif,
        color: SubtitleColor.yellow,
        edge: SubtitleEdge.shadow,
        background: SubtitleBackground.navy,
        backgroundOpacity: 75,
        position: SubtitlePosition.top,
      );

      await settings.save(const AppSettings(subtitleStyle: style));

      expect((await settings.watch().first).subtitleStyle, style);
    });

    test('une apparence illisible revient aux valeurs par défaut', () async {
      await db.customStatement(
        "INSERT INTO app_settings VALUES ('subtitle_color', 'violet'), "
        "('subtitle_background_opacity', '33')",
      );

      final style = (await SettingsRepositoryImpl(
        db,
      ).watch().first).subtitleStyle;

      expect(style.color, SubtitleColor.white);
      expect(style.backgroundOpacity, 50);
    });

    test('la progression survit à une resynchronisation', () async {
      await importFixture();
      final progress = WatchProgressRepositoryImpl(db);
      final movie = (await catalog.movies(
        sourceId,
        const PageRequest(),
      )).items.single;
      await progress.save(
        WatchProgress(
          sourceId: sourceId,
          contentKey: movie.contentKey,
          kind: ContentKind.movie,
          title: movie.title,
          position: const Duration(minutes: 10),
          duration: const Duration(minutes: 120),
          updatedAt: now,
          locator: movie.locator,
        ),
      );

      await importFixture();

      final resumed = await progress.continueWatching(sourceId);
      expect(resumed.single.position, const Duration(minutes: 10));
      final refreshed = (await catalog.movies(
        sourceId,
        const PageRequest(),
      )).items.single;
      expect(refreshed.contentKey, resumed.single.contentKey);
    });
  });
}
