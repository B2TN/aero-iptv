import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

const Series _series = Series(
  id: 7,
  title: 'Abysses',
  groupingKey: 'abysses',
  versionCount: 2,
  posterUrl: 'http://p/7.png',
);

Episode _episode(int season, int number) => Episode(
  id: season * 100 + number,
  seriesEntryId: 7,
  season: season,
  number: number,
  title: 'Abysses',
  contentKey: 'fr:$season$number',
  locator: DirectStream('http://s/fr/$season$number.mkv'),
);

WatchProgress _seen(
  int season,
  int number, {
  String version = 'en',
  bool finished = false,
}) => WatchProgress(
  sourceId: 1,
  contentKey: '$version:$season$number',
  kind: ContentKind.series,
  title: 'Abysses',
  position: const Duration(minutes: 20),
  duration: const Duration(minutes: 45),
  updatedAt: DateTime.utc(2026, 11, 13),
  locator: DirectStream('http://s/$version/$season$number.mkv'),
  workKey: WorkKeys.episode('abysses', season, number),
  seriesKey: 'abysses',
  season: season,
  episode: number,
  finished: finished,
);

final class _Progress implements WatchProgressRepository {
  final Map<String, WatchProgress> saved = {};
  final List<String> removed = [];

  @override
  Future<void> save(WatchProgress progress) async =>
      saved[progress.contentKey] = progress;

  @override
  Future<void> remove(int sourceId, String contentKey) async =>
      removed.add(contentKey);

  @override
  Future<List<WatchProgress>> continueWatching(
    int sourceId, {
    int limit = 20,
  }) async => const [];

  @override
  Future<List<WatchProgress>> history(int sourceId, {int limit = 500}) async =>
      const [];

  @override
  Future<List<WatchProgress>> progressOf(int sourceId, String key) async =>
      const [];

  @override
  Future<void> hide(int sourceId, String groupKey) async {}
}

void main() {
  final now = DateTime.utc(2026, 11, 19, 20);
  late _Progress progress;
  late MarkEpisodes mark;

  setUp(() {
    progress = _Progress();
    mark = MarkEpisodes(progress, clock: () => now);
  });

  test('un épisode jamais commencé est vu dans la version montrée', () async {
    await mark.watched(1, _series, [_episode(1, 3)], SeriesProgress(const []));

    final saved = progress.saved['fr:13']!;
    expect(saved.finished, isTrue);
    expect(saved.fraction, 1);
    expect(saved.workKey, WorkKeys.episode('abysses', 1, 3));
    expect(saved.seriesKey, 'abysses');
    expect((saved.season, saved.episode), (1, 3));
    expect(saved.updatedAt, now);
    expect(saved.posterUrl, 'http://p/7.png');
  });

  test('un épisode commencé reste dans sa version, fini', () async {
    await mark.watched(1, _series, [
      _episode(1, 2),
    ], SeriesProgress([_seen(1, 2)]));

    expect(progress.saved.keys, ['en:12']);
    final saved = progress.saved['en:12']!;
    expect(saved.finished, isTrue);
    expect(saved.position, saved.duration);
  });

  test('un épisode déjà vu ne change pas', () async {
    await mark.watched(1, _series, [
      _episode(1, 1),
      _episode(1, 2),
    ], SeriesProgress([_seen(1, 1, finished: true)]));

    expect(progress.saved.keys, ['fr:12']);
  });

  test('non vu oublie toutes les versions de l épisode, et lui seul', () async {
    await mark.unwatched(
      1,
      [_episode(1, 2)],
      SeriesProgress([
        _seen(1, 2),
        _seen(1, 2, version: 'fr', finished: true),
        _seen(1, 3),
      ]),
    );

    expect(progress.removed, unorderedEquals(['en:12', 'fr:12']));
  });
}
