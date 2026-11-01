import 'content_kind.dart';

/// Contenu populaire signalé par le service de tendances.
final class TrendingItem {
  const TrendingItem({
    required this.kind,
    required this.title,
    required this.originalTitle,
    this.overview,
    this.posterUrl,
    this.backdropUrl,
  });

  /// [ContentKind.movie] ou [ContentKind.series].
  final ContentKind kind;
  final String title;
  final String originalTitle;
  final String? overview;
  final String? posterUrl;
  final String? backdropUrl;
}
