import 'movie.dart';
import 'series.dart';
import 'watch_progress.dart';

/// Contenu mis en avant dans le carrousel de l'accueil.
final class HeroItem {
  const HeroItem({
    required this.title,
    this.overview,
    this.imageUrl,
    this.movie,
    this.series,
  });

  final String title;
  final String? overview;

  /// Image large du service de tendances, ou affiche de la playlist.
  final String? imageUrl;

  /// Contenu de la playlist à lire. Un seul des deux est renseigné.
  final Movie? movie;
  final Series? series;
}

/// Contenu de l'écran d'accueil.
final class HomeFeed {
  const HomeFeed({
    required this.hero,
    required this.continueWatching,
    required this.series,
    required this.movies,
  });

  final List<HeroItem> hero;
  final List<WatchProgress> continueWatching;
  final List<Series> series;
  final List<Movie> movies;

  bool get isEmpty =>
      hero.isEmpty &&
      continueWatching.isEmpty &&
      series.isEmpty &&
      movies.isEmpty;
}
