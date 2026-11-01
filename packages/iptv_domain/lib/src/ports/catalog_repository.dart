import '../common/page.dart';
import '../entities/media_version.dart';
import '../entities/episode.dart';
import '../entities/movie.dart';
import '../entities/season.dart';
import '../entities/series.dart';

/// Accès aux films et aux séries.
abstract interface class CatalogRepository {
  Future<Page<Movie>> movies(int sourceId, PageRequest page);

  /// Films dont l'audio est en [language], dans l'ordre du catalogue.
  Future<List<Movie>> moviesInLanguage(
    int sourceId,
    String language,
    PageRequest page,
  );

  Future<Movie?> movieById(int movieId);

  /// Film du catalogue actif, retrouvé depuis une position de lecture.
  Future<Movie?> movieByContentKey(int sourceId, String contentKey);

  /// Épisode du catalogue actif et sa série, retrouvés de la même façon.
  Future<(Series, Episode)?> episodeByContentKey(
    int sourceId,
    String contentKey,
  );

  /// Films dont le titre normalisé figure dans [titleKeys].
  Future<List<Movie>> moviesByTitleKeys(int sourceId, Set<String> titleKeys);

  /// [grouped] applique le réglage de fusion des versions. Une série fusionnée
  /// prend le titre et l'affiche de sa version la plus proche de [language].
  Future<Page<Series>> series(
    int sourceId,
    PageRequest page, {
    required bool grouped,
    required String language,
  });

  Future<Series?> seriesById(int seriesEntryId);

  /// Séries dont une version porte un titre normalisé de [titleKeys], indexées
  /// par ce titre : celui affiché, choisi selon [language], peut être un autre.
  Future<Map<String, Series>> seriesByTitleKeys(
    int sourceId,
    Set<String> titleKeys, {
    required bool grouped,
    required String language,
  });

  /// Versions d'une série, pour le sélecteur de version.
  Future<List<MediaVersion>> versionsOf(int sourceId, String groupingKey);

  /// Saisons d'une version. Pour une source Xtream, les épisodes sont chargés
  /// à la première ouverture, puis conservés en base.
  Future<List<Season>> seasonsOf(int sourceId, int seriesEntryId);
}
