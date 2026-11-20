import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

/// Deux versions d'« Abysses » : la VF (entrée 1) et la VO (entrée 2), chacune
/// avec la saison 1, épisodes 1 à 3.
const Series _abysses = Series(
  id: 1,
  title: 'Abysses',
  groupingKey: 'abysses',
  versionCount: 2,
);

String _key(int entry, int number) => 'x:e:$entry$number';

Episode _episode(int entry, int number) => Episode(
  id: entry * 100 + number,
  seriesEntryId: entry,
  season: 1,
  number: number,
  title: 'Abysses',
  contentKey: _key(entry, number),
  locator: DirectStream('http://s/$entry/$number.mkv'),
);

final class _Catalog implements CatalogRepository {
  @override
  Future<(Series, Episode)?> episodeByContentKey(
    int sourceId,
    String contentKey,
  ) async {
    for (final entry in [1, 2]) {
      for (final number in [1, 2, 3]) {
        if (_key(entry, number) == contentKey) {
          return (_abysses, _episode(entry, number));
        }
      }
    }
    return null;
  }

  @override
  Future<List<Season>> seasonsOf(int sourceId, int seriesEntryId) async => [
    Season(
      number: 1,
      episodes: [
        for (final number in [1, 2, 3]) _episode(seriesEntryId, number),
      ],
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _History implements WatchProgressRepository {
  _History(this.items);

  final List<WatchProgress> items;

  @override
  Future<List<WatchProgress>> history(int sourceId, {int limit = 500}) async =>
      items;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Reprise d'un épisode, plus récente quand [minute] est plus grand.
WatchProgress _watched(
  int entry,
  int number, {
  required int minute,
  int position = 20,
  bool finished = false,
}) => WatchProgress(
  sourceId: 1,
  contentKey: _key(entry, number),
  kind: ContentKind.series,
  title: 'Abysses',
  position: Duration(minutes: position),
  duration: const Duration(minutes: 42),
  updatedAt: DateTime.utc(2026, 11, 18, 20, minute),
  locator: DirectStream('http://s/$entry/$number.mkv'),
  workKey: WorkKeys.episode('abysses', 1, number),
  seriesKey: 'abysses',
  season: 1,
  episode: number,
  finished: finished,
);

WatchProgress _movie(
  String title, {
  required int minute,
  bool finished = false,
}) => WatchProgress(
  sourceId: 1,
  contentKey: 'x:m:$title$minute',
  kind: ContentKind.movie,
  title: title,
  position: const Duration(minutes: 30),
  duration: const Duration(minutes: 100),
  updatedAt: DateTime.utc(2026, 11, 18, 20, minute),
  locator: const DirectStream('http://s/film.mkv'),
  workKey: WorkKeys.movie(title),
  finished: finished,
);

/// L'historique arrive du plus récent au plus ancien.
Future<List<WatchProgress>> _row(List<WatchProgress> history) async =>
    (await ContinueWatching(_History(history), _Catalog())(1)).items;

void main() {
  test('une seule entrée par série, sur l épisode le plus avancé', () async {
    final row = await _row([
      _watched(1, 1, minute: 3, position: 10),
      _watched(1, 2, minute: 2, position: 30),
    ]);

    expect(row.single.episode, 2);
    expect(row.single.position, const Duration(minutes: 30));
  });

  test('dans la dernière version regardée', () async {
    // L'épisode 2 a été vu en VF, puis l'épisode 1 en VO : l'entrée montre
    // l'épisode 2, en VO, à sa position de la VF.
    final row = await _row([
      _watched(2, 1, minute: 5, position: 10),
      _watched(1, 2, minute: 4, position: 30),
    ]);

    final entry = row.single;
    expect(entry.episode, 2);
    expect(entry.contentKey, _key(2, 2));
    expect(entry.position, const Duration(minutes: 30));
  });

  test('un épisode fini propose le suivant, pas encore commencé', () async {
    final row = await _row([_watched(1, 2, minute: 5, finished: true)]);

    final entry = row.single;
    expect(entry.episode, 3);
    expect(entry.contentKey, _key(1, 3));
    expect(entry.position, Duration.zero);
    expect(entry.finished, isFalse);
  });

  test('après le dernier épisode disponible, la série est à jour', () async {
    final row = await ContinueWatching(
      _History([
        _watched(1, 2, minute: 4, finished: true),
        _watched(1, 3, minute: 5, finished: true),
      ]),
      _Catalog(),
    )(1);

    expect(row.items, isEmpty);
    final caughtUp = row.caughtUp.single;
    expect(caughtUp.progress.episode, 3);
    expect(caughtUp.series.title, 'Abysses');
  });

  test('un épisode en cours n est pas une série à jour', () async {
    final row = await ContinueWatching(
      _History([_watched(1, 3, minute: 5)]),
      _Catalog(),
    )(1);

    expect(row.items.single.episode, 3);
    expect(row.caughtUp, isEmpty);
  });

  test('les versions d un film ne font qu une entrée', () async {
    final row = await _row([
      _movie('Dune', minute: 6),
      _movie('Dune', minute: 4),
      _movie('Tenet', minute: 3),
    ]);

    expect([for (final item in row) item.title], ['Dune', 'Tenet']);
    expect(row.first.updatedAt.minute, 6);
  });

  test('un film fini disparaît', () async {
    final row = await _row([
      _movie('Dune', minute: 6, finished: true),
      _movie('Dune', minute: 4),
    ]);

    expect(row, isEmpty);
  });

  test('la série regardée en dernier passe en premier', () async {
    final row = await _row([
      _movie('Dune', minute: 9),
      _watched(1, 1, minute: 8),
      _movie('Tenet', minute: 7),
    ]);

    expect([for (final item in row) item.title], ['Dune', 'Abysses', 'Tenet']);
  });
}
