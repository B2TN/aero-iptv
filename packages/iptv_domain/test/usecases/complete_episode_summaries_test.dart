import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

final class _Catalog implements CatalogRepository {
  final Map<String, String> saved = {};
  int? savedFor;

  @override
  Future<String?> tmdbIdOfEpisode(int sourceId, String contentKey) async =>
      '1399';

  @override
  Future<void> saveEpisodeOverviews(
    int seriesEntryId,
    Map<String, String> overviews,
  ) async {
    savedFor = seriesEntryId;
    saved.addAll(overviews);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Summaries implements EpisodeSummaryRepository {
  _Summaries(this.found);

  final Map<int, String> found;
  final List<({String? tmdbId, int season, String language})> asked = [];

  @override
  Future<Map<int, String>> seasonSummaries({
    required String title,
    int? year,
    String? tmdbId,
    required int season,
    required String language,
  }) async {
    asked.add((tmdbId: tmdbId, season: season, language: language));
    return found;
  }
}

Episode _episode(int number, {String? overview}) => Episode(
  id: number,
  seriesEntryId: 8,
  season: 2,
  number: number,
  title: 'Épisode $number',
  contentKey: 'x:e:$number',
  locator: const DirectStream('http://s/e.mkv'),
  overview: overview,
);

void main() {
  test('complète les épisodes sans résumé et les garde', () async {
    final catalog = _Catalog();
    final summaries = _Summaries({1: 'Un.', 2: 'Deux.', 3: 'Trois.'});
    final season = Season(
      number: 2,
      episodes: [
        _episode(1, overview: 'Celui du fournisseur.'),
        _episode(2),
        _episode(3, overview: '  '),
        _episode(4),
      ],
    );

    final found = await CompleteEpisodeSummaries(catalog, summaries)(
      1,
      title: 'Abysses',
      year: 2026,
      season: season,
      language: 'fr',
    );

    expect(found, {'x:e:2': 'Deux.', 'x:e:3': 'Trois.'});
    expect(catalog.saved, found);
    expect(catalog.savedFor, 8);
    expect(summaries.asked.single, (tmdbId: '1399', season: 2, language: 'fr'));
  });

  test('ne demande rien quand tout est décrit', () async {
    final summaries = _Summaries({});
    final found = await CompleteEpisodeSummaries(_Catalog(), summaries)(
      1,
      title: 'Abysses',
      season: Season(number: 2, episodes: [_episode(1, overview: 'Déjà là.')]),
      language: 'fr',
    );
    expect(found, isEmpty);
    expect(summaries.asked, isEmpty);
  });
}
