/// Version d'une série, proposée dans le sélecteur de version.
final class MediaVersion {
  const MediaVersion({
    required this.seriesEntryId,
    required this.label,
    required this.rawTitle,
    this.posterUrl,
    this.variant,
  });

  final int seriesEntryId;

  /// Langue ou variante, par exemple « VF » ou « VOSTFR ».
  /// Vaut le titre d'origine si la langue n'a pas été reconnue.
  final String label;
  final String rawTitle;
  final String? posterUrl;

  /// Bouquet d'origine, quand plusieurs versions portent le même libellé.
  final String? variant;
}
