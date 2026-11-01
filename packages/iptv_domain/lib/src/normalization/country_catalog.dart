import 'text_folding.dart';

/// Pays reconnu, avec ses préfixes de playlist et ses noms courants.
final class _CountryInfo {
  const _CountryInfo(this.code, this.prefixes, this.names);

  final String code;
  final List<String> prefixes;
  final List<String> names;
}

/// Dictionnaire des pays. Pour en ajouter un, il suffit d'ajouter une ligne.
///
/// `ARB`, `AFR`, `LAT` et `EXYU` sont des pseudo-codes : les fournisseurs
/// classent souvent leurs chaînes par région. `AR` désigne l'arabe et non
/// l'Argentine, dont le préfixe reste `ARG`.
const List<_CountryInfo> _countries = [
  _CountryInfo(
    'FR',
    ['FR', 'FRA'],
    ['FRANCE', 'FRENCH', 'FRANÇAIS', 'FRANÇAISE'],
  ),
  _CountryInfo(
    'GB',
    ['UK', 'GB', 'EN', 'ENG'],
    ['UNITED KINGDOM', 'ROYAUME UNI', 'BRITISH', 'ENGLAND', 'ANGLETERRE'],
  ),
  _CountryInfo(
    'US',
    ['US', 'USA'],
    ['UNITED STATES', 'ÉTATS UNIS', 'ETATS UNIS', 'USA', 'AMERICA'],
  ),
  _CountryInfo(
    'DE',
    ['DE', 'GER', 'DEU'],
    ['GERMANY', 'ALLEMAGNE', 'DEUTSCHLAND', 'GERMAN', 'DEUTSCH'],
  ),
  _CountryInfo(
    'ES',
    ['ES', 'ESP'],
    ['SPAIN', 'ESPAGNE', 'ESPAÑA', 'SPANISH', 'ESPAÑOL'],
  ),
  _CountryInfo('IT', ['IT', 'ITA'], ['ITALY', 'ITALIE', 'ITALIA', 'ITALIAN']),
  _CountryInfo('PT', ['PT', 'POR'], ['PORTUGAL', 'PORTUGUESE']),
  _CountryInfo(
    'NL',
    ['NL'],
    ['NETHERLANDS', 'PAYS BAS', 'HOLLAND', 'NEDERLAND', 'DUTCH'],
  ),
  _CountryInfo('BE', ['BE'], ['BELGIUM', 'BELGIQUE', 'BELGIË']),
  _CountryInfo('CH', ['CH'], ['SWITZERLAND', 'SUISSE', 'SCHWEIZ']),
  _CountryInfo('AT', ['AT'], ['AUSTRIA', 'AUTRICHE', 'ÖSTERREICH']),
  _CountryInfo('LU', ['LU'], ['LUXEMBOURG']),
  _CountryInfo('IE', ['IE'], ['IRELAND', 'IRLANDE']),
  _CountryInfo('PL', ['PL', 'POL'], ['POLAND', 'POLOGNE', 'POLSKA']),
  _CountryInfo('RO', ['RO'], ['ROMANIA', 'ROUMANIE']),
  _CountryInfo('GR', ['GR'], ['GREECE', 'GRÈCE']),
  _CountryInfo(
    'TR',
    ['TR', 'TUR'],
    ['TURKEY', 'TURQUIE', 'TÜRKIYE', 'TURKISH'],
  ),
  _CountryInfo('RU', ['RU', 'RUS'], ['RUSSIA', 'RUSSIE']),
  _CountryInfo('UA', ['UA'], ['UKRAINE']),
  _CountryInfo('SE', ['SE'], ['SWEDEN', 'SUÈDE', 'SVERIGE']),
  _CountryInfo('NO', ['NO'], ['NORWAY', 'NORVÈGE', 'NORGE']),
  _CountryInfo('DK', ['DK'], ['DENMARK', 'DANEMARK', 'DANMARK']),
  _CountryInfo('FI', ['FI'], ['FINLAND', 'FINLANDE', 'SUOMI']),
  _CountryInfo('CZ', ['CZ'], ['CZECH', 'TCHÉQUIE']),
  _CountryInfo('HU', ['HU'], ['HUNGARY', 'HONGRIE']),
  _CountryInfo('AL', ['AL'], ['ALBANIA', 'ALBANIE']),
  _CountryInfo('CA', ['CA'], ['CANADA', 'QUÉBEC', 'QUEBEC']),
  _CountryInfo('BR', ['BR'], ['BRAZIL', 'BRÉSIL', 'BRASIL']),
  _CountryInfo('MX', ['MX'], ['MEXICO', 'MEXIQUE']),
  _CountryInfo('AR', ['ARG'], ['ARGENTINA', 'ARGENTINE']),
  _CountryInfo('MA', ['MA'], ['MOROCCO', 'MAROC']),
  _CountryInfo('DZ', ['DZ', 'ALG'], ['ALGERIA', 'ALGÉRIE']),
  _CountryInfo('TN', ['TN', 'TUN'], ['TUNISIA', 'TUNISIE']),
  _CountryInfo('EG', ['EG'], ['EGYPT', 'ÉGYPTE']),
  _CountryInfo('SA', ['SA', 'KSA'], ['SAUDI', 'ARABIE SAOUDITE']),
  _CountryInfo('AE', ['AE', 'UAE'], ['EMIRATES', 'ÉMIRATS', 'DUBAI']),
  _CountryInfo('LB', ['LB'], ['LEBANON', 'LIBAN']),
  _CountryInfo('IQ', ['IQ'], ['IRAQ', 'IRAK']),
  _CountryInfo('IN', ['IN'], ['INDIA', 'INDE']),
  _CountryInfo('PK', ['PK'], ['PAKISTAN']),
  _CountryInfo('CN', ['CN'], ['CHINA', 'CHINE']),
  _CountryInfo('JP', ['JP'], ['JAPAN', 'JAPON']),
  _CountryInfo('KR', ['KR'], ['KOREA', 'CORÉE']),
  _CountryInfo('AU', ['AU'], ['AUSTRALIA', 'AUSTRALIE']),
  _CountryInfo('ZA', ['ZA'], ['SOUTH AFRICA', 'AFRIQUE DU SUD']),
  _CountryInfo('ARB', ['AR', 'ARA', 'ARAB'], ['ARABIC', 'ARABE', 'ARAB']),
  _CountryInfo('AFR', ['AF', 'AFR'], ['AFRICA', 'AFRIQUE']),
  _CountryInfo('LAT', ['LAT'], ['LATIN AMERICA', 'LATINO', 'LATAM', 'LATINA']),
  _CountryInfo('EXYU', ['EXYU'], ['EX YU', 'EX-YU', 'EXYU']),
];

final Map<String, String> _byPrefix = {
  for (final country in _countries)
    for (final prefix in country.prefixes) prefix: country.code,
};

final Map<String, String> _byFoldedName = {
  for (final country in _countries)
    for (final name in country.names)
      lowerWithoutDiacritics(name): country.code,
};

/// Noms avec et sans accents, triés du plus long au plus court : « AFRIQUE DU
/// SUD » doit l'emporter sur « AFRIQUE ».
final RegExp _namePattern = () {
  final names = <String>{
    for (final country in _countries)
      for (final name in country.names) ...[name, lowerWithoutDiacritics(name)],
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  return RegExp(
    '(?<![\\p{L}\\p{N}])(?:${names.map(RegExp.escape).join('|')})'
    '(?![\\p{L}\\p{N}])',
    caseSensitive: false,
    unicode: true,
  );
}();

/// Identifiant iptv-org ou XMLTV : `TF1.fr`, `BBCOne.uk`, `TF1.fr@SD`.
final RegExp _tvgIdSuffix = RegExp(
  r'\.([a-z]{2})(?:@\w+)?$',
  caseSensitive: false,
);

/// Dictionnaire des pays présents dans les playlists.
abstract final class CountryCatalog {
  /// Retourne le code du préfixe [token], par exemple `UK` donne `GB`.
  static String? fromPrefix(String token) => _byPrefix[token.toUpperCase()];

  /// Cherche un nom de pays dans [text], par exemple dans un `group-title`.
  static String? fromText(String text) {
    final match = _namePattern.firstMatch(text);
    return match == null
        ? null
        : _byFoldedName[lowerWithoutDiacritics(match[0]!)];
  }

  /// Déduit le pays d'un identifiant de guide.
  ///
  /// Ces identifiants suivent les codes ISO : `.ar` y désigne l'Argentine.
  static String? fromTvgId(String tvgId) {
    final match = _tvgIdSuffix.firstMatch(tvgId);
    if (match == null) return null;
    final code = match[1]!.toUpperCase();
    return code == 'AR' ? 'AR' : fromPrefix(code);
  }

  /// Retire de [text] les noms de pays. « FRANCE SPORT » devient « SPORT ».
  static String removeNames(String text) => text.replaceAll(_namePattern, ' ');
}
