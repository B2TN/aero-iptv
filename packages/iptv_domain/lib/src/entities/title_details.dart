/// Ce que la playlist dit d'un film ou d'une série : résumé, genre et durée.
///
/// Tous les champs sont facultatifs : beaucoup de playlists n'en donnent aucun,
/// et une playlist M3U jamais.
final class TitleDetails {
  const TitleDetails({this.overview, this.genre, this.runtime});

  /// Aucune information connue.
  static const TitleDetails none = TitleDetails();

  final String? overview;

  /// Genres tels que le fournisseur les écrit, par exemple « Drame, Thriller ».
  final String? genre;

  /// Durée d'un film, ou d'un épisode type pour une série.
  final Duration? runtime;

  bool get isEmpty => overview == null && genre == null && runtime == null;
}
