import '../entities/season.dart';
import '../ports/catalog_repository.dart';
import '../ports/episode_summary_repository.dart';

/// Complète les résumés d'épisodes que le fournisseur ne donne pas, depuis une
/// base de métadonnées, et les garde dans le catalogue : la fiche suivante les
/// affiche tout de suite, sans rien redemander.
final class CompleteEpisodeSummaries {
  const CompleteEpisodeSummaries(this._catalog, this._summaries);

  final CatalogRepository _catalog;
  final EpisodeSummaryRepository _summaries;

  /// Résumés trouvés pour les épisodes de [season] de la série [title] qui
  /// n'en avaient pas, par `contentKey`. [language] est la langue de
  /// l'application.
  Future<Map<String, String>> call(
    int sourceId, {
    required String title,
    int? year,
    required Season season,
    required String language,
  }) async {
    final missing = [
      for (final episode in season.episodes)
        if (episode.overview?.trim().isEmpty ?? true) episode,
    ];
    if (missing.isEmpty) return const {};
    final first = missing.first;
    final found = await _summaries.seasonSummaries(
      title: title,
      year: year,
      tmdbId: await _catalog.tmdbIdOfEpisode(sourceId, first.contentKey),
      season: season.number,
      language: language,
    );
    final completed = <String, String>{
      for (final episode in missing) episode.contentKey: ?found[episode.number],
    };
    if (completed.isNotEmpty) {
      await _catalog.saveEpisodeOverviews(first.seriesEntryId, completed);
    }
    return completed;
  }
}
