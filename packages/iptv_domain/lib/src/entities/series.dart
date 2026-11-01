/// Série du catalogue.
///
/// En vue regroupée, elle fusionne toutes les versions de même [groupingKey].
final class Series {
  const Series({
    required this.id,
    required this.title,
    required this.groupingKey,
    required this.versionCount,
    this.year,
    this.posterUrl,
    this.category,
  });

  final int id;
  final String title;
  final String groupingKey;

  /// Nombre de versions. Au-delà de 1, le clic ouvre le sélecteur de version.
  final int versionCount;
  final int? year;
  final String? posterUrl;
  final String? category;
}
