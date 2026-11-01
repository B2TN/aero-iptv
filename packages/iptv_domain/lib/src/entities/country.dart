/// Pays présent dans une playlist, affiché dans la grille de drapeaux.
final class Country {
  const Country({required this.code, required this.channelCount});

  /// Code ISO 3166-1 alpha-2, ou pseudo-code de [CountryCatalog].
  /// `null` regroupe les chaînes dont le pays est inconnu.
  final String? code;
  final int channelCount;
}
