/// Étiquettes affichées dans le sélecteur de version.
const Map<String, String> _shortTags = {
  'FR': 'FR',
  'FRA': 'FR',
  'FRE': 'FR',
  'VF': 'VF',
  'VFF': 'VF',
  'VFQ': 'VFQ',
  'VO': 'VO',
  'EN': 'EN',
  'ENG': 'EN',
  'UK': 'EN',
  'US': 'EN',
  'DE': 'DE',
  'GER': 'DE',
  'DEU': 'DE',
  'ES': 'ES',
  'ESP': 'ES',
  'SPA': 'ES',
  'LAT': 'LATINO',
  'IT': 'IT',
  'ITA': 'IT',
  'PT': 'PT',
  'POR': 'PT',
  'AR': 'AR',
  'ARA': 'AR',
  'TR': 'TR',
  'TUR': 'TR',
  'NL': 'NL',
  'PL': 'PL',
  'POL': 'PL',
  'RU': 'RU',
  'RUS': 'RU',
};

/// Étiquettes assez longues pour être reconnues sans crochets en fin de titre.
const Map<String, String> _strongTags = {
  'FRENCH': 'FR',
  'TRUEFRENCH': 'VF',
  'VOSTFR': 'VOSTFR',
  'VOST': 'VOST',
  'MULTI': 'MULTI',
  'DUAL': 'MULTI',
  'ENGLISH': 'EN',
  'GERMAN': 'DE',
  'DEUTSCH': 'DE',
  'SPANISH': 'ES',
  'LATINO': 'LATINO',
  'ITALIAN': 'IT',
  'PORTUGUESE': 'PT',
  'ARABIC': 'AR',
  'TURKISH': 'TR',
  'DUTCH': 'NL',
};

/// Reconnaît les mentions de langue d'un titre.
abstract final class LanguageParser {
  /// Retourne l'étiquette normalisée de [token], ou `null`.
  static String? fromToken(String token) {
    final upper = token.toUpperCase();
    return _strongTags[upper] ?? _shortTags[upper];
  }

  /// Retourne l'étiquette de [token] seulement s'il est sans ambiguïté.
  ///
  /// Un code court en fin de titre reste ignoré : « Stephen King's IT » n'est
  /// pas une version italienne.
  static String? fromStrongToken(String token) =>
      token == token.toUpperCase() ? _strongTags[token] : null;
}
