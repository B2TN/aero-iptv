/// Résumés d'épisodes tirés d'une base de métadonnées (TMDB, TVmaze), pour
/// ceux que le fournisseur ne donne pas.
abstract interface class EpisodeSummaryRepository {
  /// Résumés des épisodes de la saison [season] de la série [title], par
  /// numéro d'épisode : dans [language] (code ISO 639-1) quand la base en a,
  /// sinon en anglais. [tmdbId] évite une recherche par titre, et [year]
  /// écarte une série homonyme.
  ///
  /// Vide si aucune base ne connaît la série, ou sans réseau : la fiche
  /// reste alors lisible, sans ces résumés.
  Future<Map<int, String>> seasonSummaries({
    required String title,
    int? year,
    String? tmdbId,
    required int season,
    required String language,
  });
}
