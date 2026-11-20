import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

const Series _abysses = Series(
  id: 1,
  title: 'Abysses',
  groupingKey: 'abysses',
  versionCount: 1,
  year: 2024,
);

/// S2 É4 vu jusqu'au bout.
final WatchProgress _last = WatchProgress(
  sourceId: 1,
  contentKey: 'x:e:24',
  kind: ContentKind.series,
  title: 'Abysses',
  position: const Duration(minutes: 42),
  duration: const Duration(minutes: 42),
  updatedAt: DateTime.utc(2026, 11, 18),
  locator: const DirectStream('http://s/24.mkv'),
  workKey: WorkKeys.episode('abysses', 2, 4),
  seriesKey: 'abysses',
  season: 2,
  episode: 4,
  finished: true,
);

UpcomingEpisode _episode(int number, int day) => UpcomingEpisode(
  season: 2,
  number: number,
  airDate: DateTime(2026, 11, day),
);

final class _Schedule implements ScheduleRepository {
  _Schedule(this.schedule, {this.fails = false});

  final ShowSchedule? schedule;
  final bool fails;
  final List<(String, int?)> asked = [];

  @override
  Future<ShowSchedule?> scheduleOf(String title, {int? year}) async {
    asked.add((title, year));
    if (fails) throw const NetworkFailure('TVmaze injoignable');
    return schedule;
  }
}

Future<Map<String, UpcomingEpisode>> _announced(_Schedule schedule) =>
    AnnouncedEpisodes(schedule)([
      CaughtUpSeries(progress: _last, series: _abysses),
    ]);

void main() {
  test('le prochain épisode annoncé, après le dernier vu', () async {
    final schedule = _Schedule(
      ShowSchedule(running: true, upcoming: [_episode(5, 26), _episode(6, 30)]),
    );

    final announced = await _announced(schedule);

    expect(announced['abysses']?.number, 5);
    expect(schedule.asked.single, ('Abysses', 2024));
  });

  test('un épisode diffusé mais absent de la playlist passe avant', () async {
    final announced = await _announced(
      _Schedule(
        ShowSchedule(
          running: true,
          aired: [_episode(4, 12), _episode(5, 19)],
          upcoming: [_episode(6, 26)],
        ),
      ),
    );

    expect(announced['abysses']?.number, 5);
  });

  test('une série terminée, sans suite, n est pas gardée', () async {
    expect(
      await _announced(_Schedule(const ShowSchedule(running: false))),
      isEmpty,
    );
    expect(await _announced(_Schedule(null)), isEmpty);
  });

  test('un calendrier injoignable ne garde rien', () async {
    expect(await _announced(_Schedule(null, fails: true)), isEmpty);
  });
}
