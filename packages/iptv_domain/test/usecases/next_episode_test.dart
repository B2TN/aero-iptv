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

void main() {
  final seasons = [
    Season(number: 2, episodes: [_episode(2, 1), _episode(2, 2)]),
    Season(number: 1, episodes: [_episode(1, 2), _episode(1, 1)]),
  ];

  test('passe à l épisode suivant de la saison', () {
    expect(nextEpisode(seasons, _episode(1, 1))?.title, 'S1 E2');
  });

  test('passe au début de la saison suivante', () {
    expect(nextEpisode(seasons, _episode(1, 2))?.title, 'S2 E1');
  });

  test('il n y a rien après le dernier épisode', () {
    expect(nextEpisode(seasons, _episode(2, 2)), isNull);
  });

  test('un épisode inconnu n a pas de suite', () {
    expect(nextEpisode(seasons, _episode(9, 9)), isNull);
  });
}
