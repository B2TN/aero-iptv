import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late WatchProgressRepositoryImpl progress;
  late int sourceId;

  WatchProgress episode(
    int number, {
    required int minute,
    bool finished = false,
  }) => WatchProgress(
    sourceId: sourceId,
    contentKey: 'x:e:$number',
    kind: ContentKind.series,
    title: 'Abysses',
    position: const Duration(minutes: 20),
    duration: const Duration(minutes: 42),
    updatedAt: DateTime.utc(2026, 11, 18, 20, minute),
    locator: const XtreamStream(
      namespace: XtreamNamespace.series,
      streamId: 7,
      extension: 'mkv',
    ),
    workKey: WorkKeys.episode('abysses', 1, number),
    seriesKey: 'abysses',
    season: 1,
    episode: number,
    finished: finished,
  );

  setUp(() async {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: configureConnection),
        closeStreamsSynchronously: true,
      ),
    );
    final added = await PlaylistRepositoryImpl(db, MemoryCredentialStore()).add(
      name: 'Essai',
      credentials: const M3uCredentials(
        playlistUrl: 'http://s.example/liste.m3u',
      ),
    );
    sourceId = (added as Ok<PlaylistSource>).value.id;
    progress = WatchProgressRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('garde l identité commune et le vu', () async {
    await progress.save(episode(1, minute: 1, finished: true));

    final saved = (await progress.history(sourceId)).single;
    expect(saved.workKey, 'e:abysses:1:1');
    expect(saved.seriesKey, 'abysses');
    expect(saved.groupKey, 'abysses');
    expect(saved.finished, isTrue);
    // Fini, il ne se reprend plus, mais compte toujours.
    expect(await progress.continueWatching(sourceId), isEmpty);
  });

  test('retirer une série retire tous ses épisodes', () async {
    await progress.save(episode(1, minute: 1));
    await progress.save(episode(2, minute: 2));

    await progress.hide(sourceId, 'abysses');

    expect(await progress.history(sourceId), isEmpty);
    expect(await progress.continueWatching(sourceId), isEmpty);
  });

  test('donne les positions d une œuvre ou d une série, retirées '
      'comprises', () async {
    await progress.save(episode(1, minute: 1, finished: true));
    await progress.save(episode(2, minute: 3));
    await progress.save(
      episode(
        2,
        minute: 2,
      ).copyWith(contentKey: 'y:e:2', position: Duration.zero),
    );
    await progress.hide(sourceId, 'abysses');

    final series = await progress.progressOf(sourceId, 'abysses');
    // La plus récente d'abord.
    expect(
      [for (final item in series) item.contentKey],
      ['x:e:2', 'y:e:2', 'x:e:1'],
    );

    final second = await progress.progressOf(sourceId, 'e:abysses:1:2');
    expect([for (final item in second) item.contentKey], ['x:e:2', 'y:e:2']);
    expect(await progress.progressOf(sourceId, 'autre'), isEmpty);
  });

  test('relire un épisode retiré le remet', () async {
    await progress.save(episode(1, minute: 1));
    await progress.hide(sourceId, 'abysses');

    await progress.save(episode(1, minute: 5));

    expect((await progress.history(sourceId)).single.contentKey, 'x:e:1');
  });
}
