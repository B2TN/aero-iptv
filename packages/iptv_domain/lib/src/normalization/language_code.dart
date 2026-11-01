import 'text_folding.dart';

/// Formes rencontrées dans les flux pour les langues de l'application.
const Map<String, String> _knownForms = {
  'fre': 'fr',
  'fra': 'fr',
  'french': 'fr',
  'francais': 'fr',
  'eng': 'en',
  'english': 'en',
  'anglais': 'en',
  'ger': 'de',
  'deu': 'de',
  'german': 'de',
  'deutsch': 'de',
  'allemand': 'de',
  'spa': 'es',
  'spanish': 'es',
  'espanol': 'es',
  'espagnol': 'es',
  'ara': 'ar',
  'arabic': 'ar',
  'arabe': 'ar',
  'ita': 'it',
  'italian': 'it',
  'por': 'pt',
  'portuguese': 'pt',
  'jpn': 'ja',
  'japanese': 'ja',
  'kor': 'ko',
  'korean': 'ko',
  'chi': 'zh',
  'zho': 'zh',
  'chinese': 'zh',
  'rus': 'ru',
  'russian': 'ru',
  'dut': 'nl',
  'nld': 'nl',
  'dutch': 'nl',
  'pol': 'pl',
  'polish': 'pl',
  'tur': 'tr',
  'turkish': 'tr',
  'hin': 'hi',
  'hindi': 'hi',
  'swe': 'sv',
  'swedish': 'sv',
  'dan': 'da',
  'danish': 'da',
  'nor': 'no',
  'norwegian': 'no',
  'fin': 'fi',
  'finnish': 'fi',
  'gre': 'el',
  'ell': 'el',
  'greek': 'el',
};

/// Ramène une langue de flux (`fre`, `French`, `fr-FR`) à son code ISO 639-1.
///
/// Retourne `null` si [value] est vide ou non reconnue.
String? normalizeLanguageCode(String? value) {
  if (value == null) return null;
  final folded = lowerWithoutDiacritics(value.trim());
  if (folded.isEmpty) return null;
  final primary = folded.split(RegExp('[-_]')).first;
  return _knownForms[primary] ?? (primary.length == 2 ? primary : null);
}
