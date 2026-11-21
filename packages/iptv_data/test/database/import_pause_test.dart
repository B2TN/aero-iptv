import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:iptv_data/iptv_data.dart' hide AppDatabase;
import 'package:iptv_data/src/adapters/catalog_batch.dart';
import 'package:iptv_data/src/adapters/playlist_source_adapter.dart';
import 'package:iptv_data/src/database/app_database.dart'
    hide AppSettings, WatchProgress;
import 'package:iptv_data/src/epg/epg_source_adapter.dart';
import 'package:iptv_data/src/import/catalog_import_pipeline.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

const m3u = M3uCredentials(playlistUrl: 'http://s.example/list.m3u');
final DateTime now = DateTime.utc(2026, 11, 21, 20);

/// Liste d'un seul tenant, dont le premier téléchargement est coupé par une
/// lecture : la pause arrive entre deux lots.
final class _InterruptedCatalog implements PlaylistSourceAdapter {
  _InterruptedCatalog(this.pause);

  final ImportPause pause;
  int calls = 0;

  @override
  Future<List<SourceSection>> open(PlaylistCredentials credentials) async => [
    SourceSection(null, _fetch),
  ];

  Stream<CatalogBatch> _fetch() async* {
    calls++;
    yield CatalogBatch([live('TF1', 'FRANCE', tvgId: 'tf1')]);
    if (calls == 1) pause.set(paused: true);
    yield CatalogBatch([live('M6', 'FRANCE', id: 2)]);
  }
}

/// Guide dont le premier téléchargement est coupé de la même façon.
final class _InterruptedGuide implements EpgSourceAdapter {
  _InterruptedGuide(this.pause);

  final ImportPause pause;
  int calls = 0;

  EpgProgramme _programme(String title, int hour) => EpgProgramme(
    epgKey: 'tf1',
    title: title,
    start: now.add(Duration(hours: hour)),
    stop: now.add(Duration(hours: hour + 1)),
  );

  @override
  Stream<List<EpgProgramme>> fetch(EpgRequest request) async* {
    calls++;
    yield [_programme('Journal', 0)];
    if (calls == 1) pause.set(paused: true);
    yield [_programme('Film', 1)];
  }
}

void main() {
  late AppDatabase db;
  late int sourceId;

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: configureConnection),
        closeStreamsSynchronously: true,
      ),
    );
    final playlists = PlaylistRepositoryImpl(db, MemoryCredentialStore());
    final added = await playlists.add(name: 'Test', credentials: m3u);
    sourceId = (added as Ok<PlaylistSource>).value.id;
  });

  tearDown(() => db.close());

  CatalogImportPipeline pipeline(
    PlaylistSourceAdapter catalog, {
    EpgSourceAdapter guide = const FakeEpgAdapter(),
  }) => CatalogImportPipeline(
    database: db,
    catalogAdapter: catalog,
    epgAdapter: guide,
    clock: () => now,
    pause: (_) async {},
  );

  Future<int> count(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  /// Laisse tourner la synchronisation : en pause, elle ne doit rien faire.
  Future<void> idle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('une lecture coupe le téléchargement, repris du début après', () async {
    final pause = ImportPause();
    final catalog = _InterruptedCatalog(pause);
    final events = <ImportProgress>[];

    final finished = pipeline(
      catalog,
    ).run(sourceId, m3u, pause: pause).forEach(events.add);
    await idle();

    expect(pause.isPaused, isTrue);
    expect(catalog.calls, 1);
    expect(
      events.map((event) => event.stage),
      isNot(contains(ImportStage.done)),
    );
    // Le début de la liste, écrit avant la pause, n'est pas gardé à moitié.
    expect(await count('live_channels'), 0);

    pause.set(paused: false);
    await finished;

    expect(catalog.calls, 2);
    expect(events.last.stage, ImportStage.done);
    // Une pause n'est pas une panne.
    expect(events.last.failedSections, isEmpty);
    expect(await count('live_channels'), 2);
  });

  test('une lecture coupe le guide, recommencé après', () async {
    final pause = ImportPause();
    final guide = _InterruptedGuide(pause);
    final events = <ImportProgress>[];

    final finished = pipeline(
      FakeCatalogAdapter([
        CatalogBatch([live('TF1', 'FRANCE', tvgId: 'tf1')]),
      ]),
      guide: guide,
    ).run(sourceId, m3u, pause: pause).forEach(events.add);
    await idle();

    expect(pause.isPaused, isTrue);
    expect(guide.calls, 1);
    // Le catalogue est déjà affiché : seul le guide attend.
    expect(await count('live_channels'), 1);

    pause.set(paused: false);
    await finished;

    expect(guide.calls, 2);
    expect(events.last.epgFailed, isFalse);
    expect(await count('epg_programmes'), 2);
  });

  test(
    'commencée pendant une lecture, elle attend sans rien télécharger',
    () async {
      final pause = ImportPause()..set(paused: true);
      final catalog = _InterruptedCatalog(ImportPause());

      final finished = pipeline(
        catalog,
      ).run(sourceId, m3u, pause: pause).toList();
      await idle();

      expect(catalog.calls, 0);
      expect(await count('live_channels'), 0);

      pause.set(paused: false);
      final events = await finished;
      expect(events.last.stage, ImportStage.done);
      expect(await count('live_channels'), 2);
    },
  );
}
