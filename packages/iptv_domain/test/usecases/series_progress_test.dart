import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

/// Deux saisons de deux épisodes, dans la version [entry].
List<Season> _seasons(int entry) => [
  for (final season in [1, 2])
    Season(
      number: season,
      episodes: [
        for (final number in [1, 2])
          Episode(
            id: entry * 100 + season * 10 + number,
            seriesEntryId: entry,
            season: season,
            number: number,
            title: 'Abysses',
            contentKey: 'v$entry:$season$number',
            locator: DirectStream('http://s/$entry/$season$number.mkv'),
          ),
      ],
    ),
];

WatchProgress _seen(
  int entry,
  int season,
  int number, {
  int minutes = 20,
  bool finished = false,
  int day = 13,
}) => WatchProgress(
  sourceId: 1,
  contentKey: 'v$entry:$season$number',
  kind: ContentKind.series,
  title: 'Abysses',
  position: Duration(minutes: minutes),
  duration: const Duration(minutes: 45),
  updatedAt: DateTime.utc(2026, 11, day),
  locator: DirectStream('http://s/$entry/$season$number.mkv'),
  workKey: WorkKeys.episode('abysses', season, number),
  seriesKey: 'abysses',
  season: season,
  episode: number,
  finished: finished,
);

void main() {
  test('donne la dernière position d un épisode, toutes versions '
      'confondues', () {
    // La plus récente d'abord : la VO a été regardée après la VF.
    final progress = SeriesProgress([
      _seen(2, 1, 2, minutes: 30, day: 14),
      _seen(1, 1, 2, minutes: 10),
    ]);

    expect(progress.of(1, 2)?.position, const Duration(minutes: 30));
    expect(progress.of(1, 2)?.contentKey, 'v2:12');
    expect(progress.of(1, 1), isNull);
  });

  test('reprend l épisode le plus avancé, dans la version demandée', () {
    final progress = SeriesProgress([
      _seen(1, 1, 1, day: 15),
      _seen(2, 2, 1, minutes: 12, day: 14),
    ]);

    final resume = progress.resumeIn(_seasons(1))!;

    expect(resume.episode.contentKey, 'v1:21');
    expect(resume.position, const Duration(minutes: 12));
  });

  test('après un épisode fini, passe au suivant depuis le début', () {
    final progress = SeriesProgress([_seen(2, 1, 2, finished: true)]);

    final resume = progress.resumeIn(_seasons(1))!;

    expect(resume.episode.contentKey, 'v1:21');
    expect(resume.position, Duration.zero);
  });

  test('rien à reprendre après le dernier épisode, ou sans rien de vu', () {
    expect(
      SeriesProgress([_seen(1, 2, 2, finished: true)]).resumeIn(_seasons(1)),
      isNull,
    );
    expect(SeriesProgress(const []).resumeIn(_seasons(1)), isNull);
  });

  test('rien à reprendre si cette version n a pas l épisode', () {
    final progress = SeriesProgress([_seen(2, 3, 1)]);

    expect(progress.resumeIn(_seasons(1)), isNull);
  });
}
