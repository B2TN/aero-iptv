import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

Episode _episode(int season, int number) => Episode(
  id: season * 100 + number,
  seriesEntryId: 1,
  season: season,
  number: number,
  title: 'S$season E$number',
  contentKey: 's$season:e$number',
  locator: const DirectStream('http://s/1.mkv'),
);

UpcomingEpisode _aired(int season, int number) => UpcomingEpisode(
  season: season,
  number: number,
  airDate: DateTime(2026, 11, number),
);

List<String> _labels(List<UpcomingEpisode> episodes) => [
  for (final episode in episodes) 'S${episode.season}E${episode.number}',
];

void main() {
  group('ShowSchedule.lateAfter', () {
    final schedule = ShowSchedule(
      running: true,
      aired: [_aired(2, 3), _aired(2, 4), _aired(2, 5)],
    );

    test('garde les épisodes diffusés après le dernier de la playlist', () {
      final seasons = [
        Season(number: 1, episodes: [_episode(1, 1), _episode(1, 2)]),
        Season(number: 2, episodes: [_episode(2, 2), _episode(2, 3)]),
      ];

      expect(_labels(schedule.lateAfter(seasons)), ['S2E4', 'S2E5']);
    });

    test('un trou plus ancien n est pas un retard', () {
      // S2E3 manque, mais la playlist a déjà S2E4 : le fournisseur ne l'a
      // jamais eu, il ne l'attend pas.
      final seasons = [
        Season(number: 2, episodes: [_episode(2, 1), _episode(2, 4)]),
      ];

      expect(_labels(schedule.lateAfter(seasons)), ['S2E5']);
    });

    test('une saison nouvelle compte, pas une saison lointaine', () {
      final seasons = [
        Season(number: 1, episodes: [_episode(1, 10)]),
      ];

      expect(_labels(schedule.lateAfter(seasons)), ['S2E3', 'S2E4', 'S2E5']);

      // Numérotation absolue : la playlist n'a qu'une « saison 1 » de cent
      // épisodes, TVmaze en est à la saison 5.
      final absolute = ShowSchedule(running: true, aired: [_aired(5, 3)]);
      expect(absolute.lateAfter(seasons), isEmpty);
    });

    test('rien n est en retard quand la playlist est à jour ou vide', () {
      final seasons = [
        Season(number: 2, episodes: [_episode(2, 5)]),
      ];

      expect(schedule.lateAfter(seasons), isEmpty);
      expect(schedule.lateAfter(const []), isEmpty);
    });
  });
}
