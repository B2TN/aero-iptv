import '../common/failure.dart';
import '../common/page.dart';
import '../entities/content_kind.dart';
import '../entities/home_feed.dart';
import '../entities/movie.dart';
import '../entities/series.dart';
import '../entities/trending_item.dart';
import '../normalization/grouping_key.dart';
import '../normalization/version_language.dart';
import '../ports/catalog_repository.dart';
import '../ports/trending_repository.dart';
import '../ports/watch_progress_repository.dart';

const int _rowSize = 20;
const int _heroSize = 5;

/// Compose l'accueil.
///
/// Les tendances sont croisées avec la playlist : proposer un titre que
/// l'abonnement ne contient pas n'aurait aucun sens. Si le service de tendances
/// est injoignable, l'accueil se rabat sur l'ordre de la playlist.
final class BuildHomeFeed {
  const BuildHomeFeed(this._catalog, this._trending, this._progress);

  final CatalogRepository _catalog;
  final TrendingRepository _trending;
  final WatchProgressRepository _progress;

  Future<HomeFeed> call(
    int sourceId, {
    required String language,
    required bool groupSeries,
    String? region,
  }) async {
    final continueWatching = await _progress.continueWatching(sourceId);
    final popularMovies = await _popular(ContentKind.movie, language, region);
    final popularSeries = await _popular(ContentKind.series, language, region);

    final hero = <HeroItem>[];
    final movies = await _matchMovies(sourceId, popularMovies, hero, language);
    final series = await _matchSeries(
      sourceId,
      popularSeries,
      hero,
      grouped: groupSeries,
      language: language,
    );

    // Les tendances d'abord, puis la playlist : une rangée reste bien remplie
    // même si l'abonnement ne contient que peu de titres en vogue.
    final moviesInLanguage = await _catalog.moviesInLanguage(
      sourceId,
      language,
      const PageRequest(limit: _rowSize),
    );
    final catalogMovies = await _catalog.movies(
      sourceId,
      const PageRequest(limit: _rowSize),
    );
    final catalogSeries = await _catalog.series(
      sourceId,
      const PageRequest(limit: _rowSize),
      grouped: groupSeries,
      language: language,
    );
    // Chaque version d'un film est une ligne du catalogue : une seule par titre.
    final shownTitles = <String>{};
    final movieRow = [...movies, ...moviesInLanguage, ...catalogMovies.items]
        .where((movie) => shownTitles.add(GroupingKey.of(movie.title)))
        .take(_rowSize)
        .toList(growable: false);
    final seriesRow = [
      ...series,
      ...catalogSeries.items.where(
        (entry) => !series.any((item) => item.groupingKey == entry.groupingKey),
      ),
    ].take(_rowSize).toList(growable: false);

    return HomeFeed(
      hero: hero.isNotEmpty
          ? hero.take(_heroSize).toList(growable: false)
          : _heroFromCatalog(seriesRow, movieRow),
      continueWatching: continueWatching,
      series: seriesRow,
      movies: movieRow,
    );
  }

  /// Le service de tendances est facultatif : son échec laisse un accueil utile.
  Future<List<TrendingItem>> _popular(
    ContentKind kind,
    String language,
    String? region,
  ) async {
    if (!_trending.isAvailable) return const [];
    try {
      return await _trending.popular(kind, language: language, region: region);
    } on Failure {
      return const [];
    }
  }

  Future<List<Movie>> _matchMovies(
    int sourceId,
    List<TrendingItem> items,
    List<HeroItem> hero,
    String language,
  ) async {
    if (items.isEmpty) return const [];

    // Un film existe souvent en plusieurs langues : celle de l'utilisateur prime.
    final versions = <String, List<Movie>>{};
    for (final movie in await _catalog.moviesByTitleKeys(
      sourceId,
      _keysOf(items),
    )) {
      (versions[GroupingKey.of(movie.title)] ??= []).add(movie);
    }
    final byKey = {
      for (final entry in versions.entries)
        entry.key: versionsByLanguage(
          entry.value,
          (movie) => movie.languageTag,
          language,
        ).first,
    };
    final matched = <Movie>[];
    for (final item in items) {
      final movie = _find(byKey, item);
      if (movie == null || matched.contains(movie)) continue;
      matched.add(movie);
      _addHero(hero, item, movie: movie);
      if (matched.length == _rowSize) break;
    }
    return matched;
  }

  Future<List<Series>> _matchSeries(
    int sourceId,
    List<TrendingItem> items,
    List<HeroItem> hero, {
    required bool grouped,
    required String language,
  }) async {
    if (items.isEmpty) return const [];
    final byKey = await _catalog.seriesByTitleKeys(
      sourceId,
      _keysOf(items),
      grouped: grouped,
      language: language,
    );
    final matched = <Series>[];
    for (final item in items) {
      final series = _find(byKey, item);
      if (series == null || matched.contains(series)) continue;
      matched.add(series);
      _addHero(hero, item, series: series);
      if (matched.length == _rowSize) break;
    }
    return matched;
  }

  Set<String> _keysOf(List<TrendingItem> items) => {
    for (final item in items) ...[
      GroupingKey.of(item.title),
      GroupingKey.of(item.originalTitle),
    ],
  };

  T? _find<T>(Map<String, T> byKey, TrendingItem item) =>
      byKey[GroupingKey.of(item.title)] ??
      byKey[GroupingKey.of(item.originalTitle)];

  void _addHero(
    List<HeroItem> hero,
    TrendingItem item, {
    Movie? movie,
    Series? series,
  }) {
    hero.add(
      HeroItem(
        title: item.title,
        overview: item.overview,
        imageUrl: item.backdropUrl ?? movie?.posterUrl ?? series?.posterUrl,
        movie: movie,
        series: series,
      ),
    );
  }

  List<HeroItem> _heroFromCatalog(List<Series> series, List<Movie> movies) => [
    for (final item in series.take(_heroSize - 2))
      HeroItem(title: item.title, imageUrl: item.posterUrl, series: item),
    for (final item in movies.take(2))
      HeroItem(title: item.title, imageUrl: item.posterUrl, movie: item),
  ];
}
