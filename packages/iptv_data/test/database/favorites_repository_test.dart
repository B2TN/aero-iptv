import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase db;
  late FavoritesRepositoryImpl favorites;
  late int sourceId;

  Favorite favorite(
    ContentKind kind,
    String key, {
    int minute = 0,
    String title = 'Titre',
  }) => Favorite(
    sourceId: sourceId,
    kind: kind,
    key: key,
    title: title,
    addedAt: DateTime.utc(2026, 11, 18, 20, minute),
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
    favorites = FavoritesRepositoryImpl(db);
  });

  tearDown(() => db.close());

  test('liste les favoris du plus récent au plus ancien', () async {
    await favorites.add(favorite(ContentKind.movie, 'dune', minute: 1));
    await favorites.add(favorite(ContentKind.series, 'abysses', minute: 2));
    await favorites.add(favorite(ContentKind.live, 'tf1', minute: 3));

    final list = await favorites.watch(sourceId).first;

    expect([for (final item in list) item.key], ['tf1', 'abysses', 'dune']);
    expect(list.first.kind, ContentKind.live);
  });

  test('un film et une série de même clé restent distincts', () async {
    await favorites.add(favorite(ContentKind.movie, 'dune'));
    await favorites.add(favorite(ContentKind.series, 'dune'));

    await favorites.remove(sourceId, ContentKind.movie, 'dune');

    final list = await favorites.watch(sourceId).first;
    expect(list.single.kind, ContentKind.series);
  });

  test('ajouter deux fois met à jour sans doublon', () async {
    await favorites.add(favorite(ContentKind.movie, 'dune', title: 'Dune'));
    await favorites.add(
      favorite(ContentKind.movie, 'dune', minute: 5, title: 'Dune (2021)'),
    );

    final list = await favorites.watch(sourceId).first;
    expect(list.single.title, 'Dune (2021)');
  });

  test('prévient à chaque changement', () async {
    final seen = <int>[];
    final subscription = favorites
        .watch(sourceId)
        .listen((list) => seen.add(list.length));
    await pumpEventQueue();

    await favorites.add(favorite(ContentKind.movie, 'dune'));
    await pumpEventQueue();
    await favorites.remove(sourceId, ContentKind.movie, 'dune');
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, [0, 1, 0]);
  });

  test('partent avec leur playlist, et seulement avec elle', () async {
    await favorites.add(favorite(ContentKind.movie, 'dune'));
    final other = await PlaylistRepositoryImpl(db, MemoryCredentialStore()).add(
      name: 'Autre',
      credentials: const M3uCredentials(
        playlistUrl: 'http://s.example/autre.m3u',
      ),
    );
    final otherId = (other as Ok<PlaylistSource>).value.id;

    await db.customStatement('DELETE FROM sources WHERE id = ?', [otherId]);
    expect(await favorites.watch(sourceId).first, hasLength(1));

    await db.customStatement('DELETE FROM sources WHERE id = ?', [sourceId]);
    expect(await favorites.watch(sourceId).first, isEmpty);
  });
}
