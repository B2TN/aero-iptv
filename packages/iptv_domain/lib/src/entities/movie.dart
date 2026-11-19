import '../normalization/grouping_key.dart';
import 'stream_locator.dart';
import 'stream_quality.dart';

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
    this.quality = StreamQuality.unknown,
    String? groupingKey,
  }) : _groupingKey = groupingKey;

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

  /// Qualité annoncée par le titre (4K, FHD…), qui distingue deux versions
  /// d'une même langue.
  final StreamQuality quality;

  final String? _groupingKey;

  /// Fiche du film, commune à toutes ses versions : le titre nettoyé, avec
  /// l'année s'il a des homonymes, ou celle d'une version traduite reconnue
  /// par TMDB ou par son affiche.
  String get groupingKey => _groupingKey ?? GroupingKey.of(title);
}
