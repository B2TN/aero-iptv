/// Chaîne affichée dans la colonne droite de Live TV.
///
/// En vue regroupée, elle représente tous les flux de même [groupingKey].
final class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.groupingKey,
    this.countryCode,
    this.logoUrl,
    this.epgKey,
  });

  final int id;
  final String name;
  final String groupingKey;
  final String? countryCode;
  final String? logoUrl;

  /// Clé de rapprochement avec le guide des programmes.
  final String? epgKey;
}
