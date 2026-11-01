import 'content_kind.dart';

/// Résultat de recherche dans les films et les séries.
final class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    this.posterUrl,
  });

  /// [ContentKind.movie] ou [ContentKind.series].
  final ContentKind kind;
  final int id;
  final String title;
  final String? posterUrl;
}
