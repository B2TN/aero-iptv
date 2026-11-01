import 'stream_locator.dart';

/// Film du catalogue.
final class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.rawTitle,
    required this.contentKey,
    required this.locator,
    this.year,
    this.posterUrl,
    this.category,
    this.languageTag,
  });

  final int id;

  /// Titre nettoyé.
  final String title;

  /// Titre d'origine de la playlist.
  final String rawTitle;

  /// Identité stable entre deux synchronisations, contrairement à [id].
  final String contentKey;
  final StreamLocator locator;
  final int? year;
  final String? posterUrl;
  final String? category;
  final String? languageTag;
}
