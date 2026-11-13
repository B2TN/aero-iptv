import '../common/page.dart';
import '../entities/search_hit.dart';

/// Recherche dans les films et les séries de la playlist.
abstract interface class SearchRepository {
  /// Suggestions prédictives pendant la saisie.
  Future<List<String>> suggest(int sourceId, String input, {int limit = 8});

  /// Chaque résultat prend le titre et l'affiche de sa version la plus proche
  /// de [language]. [groupMovies] à `false` montre chaque version d'un film à
  /// part, avec sa langue.
  Future<Page<SearchHit>> search(
    int sourceId,
    String query,
    PageRequest page, {
    required String language,
    bool groupMovies = true,
  });
}
