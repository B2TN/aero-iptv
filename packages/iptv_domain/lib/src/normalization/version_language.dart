/// Libellés des fournisseurs, ramenés à la langue de l'audio.
const Map<String, String> _audioLanguages = {
  'AF': 'af',
  'AL': 'sq',
  'AR': 'ar',
  'ARA': 'ar',
  'BG': 'bg',
  'BN': 'bn',
  'BR': 'pt',
  'DA': 'da',
  'DE': 'de',
  'DK': 'da',
  'EL': 'el',
  'EN': 'en',
  'ES': 'es',
  'EX': 'sh',
  'FI': 'fi',
  'FR': 'fr',
  'GR': 'el',
  'HI': 'hi',
  'HU': 'hu',
  'IN': 'hi',
  'IND': 'hi',
  'IR': 'fa',
  'ISR': 'he',
  'IT': 'it',
  'KN': 'kn',
  'LAT': 'lat',
  'LATINO': 'lat',
  'ML': 'ml',
  'MR': 'mr',
  'NL': 'nl',
  'NO': 'no',
  'PB': 'pa',
  'PH': 'fil',
  'PK': 'ur',
  'PL': 'pl',
  'PT': 'pt',
  'QFR': 'qc',
  'RO': 'ro',
  'RU': 'ru',
  'SC': 'scn',
  'SE': 'sv',
  'SOM': 'so',
  'TL': 'te',
  'TM': 'ta',
  'TR': 'tr',
  'UK': 'en',
  'UR': 'ur',
  'US': 'en',
  'VF': 'fr',
  'VFF': 'fr',
  'VFQ': 'qc',
};

/// Variantes régionales : préférables à l'anglais dans leur langue de base.
const Map<String, String> _regionalVariants = {'qc': 'fr', 'lat': 'es'};

final RegExp _tagSeparator = RegExp('[ -]+');

/// Un libellé de fournisseur, et non le titre brut d'une version sans libellé.
final RegExp _providerLabel = RegExp(r'^[A-Z0-9 -]{1,16}$');

bool isProviderLabel(String label) => _providerLabel.hasMatch(label);

/// Mentions d'un libellé : `4K-DE` en contient deux.
List<String> labelTags(String label) => label.split(_tagSeparator);

/// Langue de l'audio d'une mention, `null` si elle n'en désigne aucune.
String? audioLanguageOfTag(String tag) => _audioLanguages[tag];

/// Langue de l'audio d'après un libellé, `null` si elle n'y figure pas.
String? audioLanguageOf(String? label) {
  if (label == null || !isProviderLabel(label)) return null;
  for (final tag in labelTags(label)) {
    final language = _audioLanguages[tag];
    if (language != null) return language;
  }
  return null;
}

/// Libellés simples qui désignent [language].
List<String> languageTags(String language) => [
  for (final entry in _audioLanguages.entries)
    if (entry.value == language) entry.key,
];

/// Rang d'une version pour [language] : plus il est bas, mieux elle convient.
///
/// La langue exacte d'abord, puis ses déclinaisons (4K, sous-titré), ses
/// variantes régionales, l'anglais, et enfin les versions sans langue connue.
int versionRank(String? label, String language) {
  final audio = audioLanguageOf(label);
  if (audio == null) return 4;
  if (audio == language) return labelTags(label!).length == 1 ? 0 : 1;
  if (_regionalVariants[audio] == language) return 2;
  return audio == 'en' ? 3 : 5;
}

/// Trie [versions] pour [language], sans changer l'ordre des versions de même
/// rang. Le premier élément donne le titre et l'affiche à montrer.
List<T> versionsByLanguage<T>(
  Iterable<T> versions,
  String? Function(T version) label,
  String language,
) {
  final ranked = [
    for (final (index, version) in versions.indexed)
      (
        rank: versionRank(label(version), language),
        index: index,
        value: version,
      ),
  ];
  ranked.sort((a, b) {
    final order = a.rank.compareTo(b.rank);
    return order != 0 ? order : a.index.compareTo(b.index);
  });
  return [for (final item in ranked) item.value];
}
