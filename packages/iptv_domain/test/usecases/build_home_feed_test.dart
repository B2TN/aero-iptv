import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

const StreamLocator locator = DirectStream('http://s/1.mkv');

Movie movie(int id, String title, {String? tag}) => Movie(
  id: id,
  title: title,
  rawTitle: title,
  contentKey: 'm$id',
  locator: locator,
  posterUrl: 'http://p/$id.png',
  languageTag: tag,
);

Series series(int id, String title) => Series(
  id: id,
  title: title,
  groupingKey: GroupingKey.of(title),
  versionCount: 1,
  posterUrl: 'http://p/$id.png',
);

TrendingItem trending(ContentKind kind, String title, {String? original}) =>
    TrendingItem(
      kind: kind,
      title: title,
      originalTitle: original ?? title,
      backdropUrl: 'http://b/$title.jpg',
    );

final class FakeCatalog implements CatalogRepository {
  @override
  Future<Movie?> movieByContentKey(int sourceId, String contentKey) async =>
      null;

  @override
  Future<(Series, Episode)?> episodeByContentKey(
    int sourceId,
    String contentKey,
  ) async => null;

  @override
  Future<String?> tmdbIdOfEpisode(int sourceId, String contentKey) async =>
      null;

  FakeCatalog({this.movieList = const [], this.seriesList = const []});

  final List<Movie> movieList;
  final List<Series> seriesList;

  @override
  Future<Page<Movie>> movies(int sourceId, PageRequest page) async =>
      Page(items: movieList, request: page);

  @override
  Future<List<Movie>> moviesInLanguage(
    int sourceId,
    String language,
    PageRequest page,
  ) async => movieList
      .where((item) => audioLanguageOf(item.languageTag) == language)
      .toList();

  @override
  Future<Page<Series>> series(
    int sourceId,
    PageRequest page, {
    required bool grouped,
    required String language,
  }) async => Page(items: seriesList, request: page);

  @override
  Future<List<Movie>> moviesByTitleKeys(
    int sourceId,
    Set<String> titleKeys,
  ) async => movieList
      .where((item) => titleKeys.contains(GroupingKey.of(item.title)))
      .toList();

  @override
  Future<Map<String, Series>> seriesByTitleKeys(
    int sourceId,
    Set<String> titleKeys, {
    required bool grouped,
    required String language,
  }) async => {
    for (final item in seriesList)
      if (titleKeys.contains(GroupingKey.of(item.title)))
        GroupingKey.of(item.title): item,
  };

  @override
  Future<Movie?> movieById(int movieId) async => null;

  @override
  Future<Series?> seriesById(int seriesEntryId) async => null;

  @override
  Future<List<Season>> seasonsOf(int sourceId, int seriesEntryId) async => [];

  @override
  Future<TitleDetails> movieDetails(int sourceId, int movieId) async =>
      TitleDetails.none;

  @override
  Future<TitleDetails> seriesDetails(int sourceId, int seriesEntryId) async =>
      TitleDetails.none;

  @override
  Future<List<MediaVersion>> versionsOf(
    int sourceId,
    String groupingKey,
  ) async => [];
}

final class FakeTrending implements TrendingRepository {
  FakeTrending({this.items = const [], this.failure, this.isAvailable = true});

  final List<TrendingItem> items;
  final Failure? failure;

  @override
  final bool isAvailable;

  @override
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    required String language,
    String? region,
  }) async {
    final error = failure;
    if (error != null) throw error;
    return items.where((item) => item.kind == kind).toList();
  }
}

final class EmptyProgress implements WatchProgressRepository {
  @override
  Future<List<WatchProgress>> continueWatching(
    int sourceId, {
    int limit = 20,
  }) async => [];

  @override
  Future<void> remove(int sourceId, String contentKey) async {}

  @override
  Future<void> save(WatchProgress progress) async {}
}

Future<HomeFeed> build(FakeCatalog catalog, FakeTrending trending) =>
    BuildHomeFeed(catalog, trending, EmptyProgress())(
      1,
      language: 'fr',
      groupSeries: true,
      region: 'FR',
    );

void main() {
  test('classe la playlist selon les tendances', () async {
    final feed = await build(
      FakeCatalog(movieList: [movie(1, 'Alpha'), movie(2, 'Beta')]),
      FakeTrending(
        items: [
          trending(ContentKind.movie, 'Beta'),
          trending(ContentKind.movie, 'Alpha'),
        ],
      ),
    );
    expect(feed.movies.map((item) => item.title), ['Beta', 'Alpha']);
  });

  test('ignore les tendances absentes de la playlist', () async {
    final feed = await build(
      FakeCatalog(movieList: [movie(1, 'Alpha')]),
      FakeTrending(
        items: [
          trending(ContentKind.movie, 'Absent'),
          trending(ContentKind.movie, 'Alpha'),
        ],
      ),
    );
    expect(feed.movies.map((item) => item.title), ['Alpha']);
    expect(feed.hero.single.title, 'Alpha');
  });

  test('rapproche aussi par le titre original', () async {
    final feed = await build(
      FakeCatalog(seriesList: [series(1, 'Breaking Bad')]),
      FakeTrending(
        items: [
          trending(
            ContentKind.series,
            'Titre traduit',
            original: 'Breaking Bad',
          ),
        ],
      ),
    );
    expect(feed.series.single.title, 'Breaking Bad');
    expect(feed.hero.single.series, isNotNull);
  });

  test('choisit la version dans la langue de l application', () async {
    final feed = await BuildHomeFeed(
      FakeCatalog(
        movieList: [
          movie(1, 'Dune', tag: 'EN'),
          movie(2, 'Dune', tag: 'FR'),
          movie(3, 'Dune', tag: 'DE'),
        ],
      ),
      FakeTrending(items: [trending(ContentKind.movie, 'Dune')]),
      EmptyProgress(),
    )(1, language: 'fr', groupSeries: true);

    expect(feed.movies.map((item) => item.id), [2]);
    expect(feed.hero.single.imageUrl, 'http://b/Dune.jpg');
  });

  test('sans la langue voulue, préfère l anglais', () async {
    final feed = await BuildHomeFeed(
      FakeCatalog(
        movieList: [
          movie(1, 'Dune', tag: 'PL'),
          movie(2, 'Dune', tag: 'EN'),
        ],
      ),
      FakeTrending(items: [trending(ContentKind.movie, 'Dune')]),
      EmptyProgress(),
    )(1, language: 'fr', groupSeries: true);

    expect(feed.movies.map((item) => item.id), [2]);
  });

  test('sans tendances, la langue de l application passe d abord', () async {
    final feed = await BuildHomeFeed(
      FakeCatalog(
        movieList: [
          movie(1, 'Dune', tag: 'EN'),
          movie(2, 'Tenet', tag: 'DE'),
          movie(3, 'Dune', tag: 'FR'),
        ],
      ),
      FakeTrending(isAvailable: false),
      EmptyProgress(),
    )(1, language: 'fr', groupSeries: true);

    expect(feed.movies.map((item) => item.id), [3, 2]);
  });

  test('se rabat sur la playlist sans service', () async {
    final feed = await build(
      FakeCatalog(movieList: [movie(1, 'Alpha')]),
      FakeTrending(isAvailable: false),
    );
    expect(feed.movies.single.title, 'Alpha');
    expect(feed.hero.single.imageUrl, 'http://p/1.png');
  });

  test('se rabat sur la playlist si le service échoue', () async {
    final feed = await build(
      FakeCatalog(movieList: [movie(1, 'Alpha')]),
      FakeTrending(failure: const NetworkFailure('hors ligne')),
    );
    expect(feed.movies.single.title, 'Alpha');
  });

  test('signale un accueil vide', () async {
    expect((await build(FakeCatalog(), FakeTrending())).isEmpty, isTrue);
  });
}
