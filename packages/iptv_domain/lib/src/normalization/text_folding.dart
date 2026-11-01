/// Lettres et chiffres décoratifs utilisés par les fournisseurs (`ᶠᴴᴰ`, `²`).
const Map<int, String> _modifierLetters = {
  0x1D2C: 'A',
  0x1D2E: 'B',
  0x1D30: 'D',
  0x1D31: 'E',
  0x1D33: 'G',
  0x1D34: 'H',
  0x1D35: 'I',
  0x1D36: 'J',
  0x1D37: 'K',
  0x1D38: 'L',
  0x1D39: 'M',
  0x1D3A: 'N',
  0x1D3C: 'O',
  0x1D3E: 'P',
  0x1D3F: 'R',
  0x1D40: 'T',
  0x1D41: 'U',
  0x2C7D: 'V',
  0x1D42: 'W',
  0x1DA0: 'F',
  0x02E2: 'S',
  0x1D9C: 'C',
  0x2070: '0',
  0x00B9: '1',
  0x00B2: '2',
  0x00B3: '3',
  0x2074: '4',
  0x2075: '5',
  0x2076: '6',
  0x2077: '7',
  0x2078: '8',
  0x2079: '9',
};

/// Blocs Unicode « mathématiques » en gras, dont A-Z, a-z et 0-9.
const int _mathBoldUpper = 0x1D400;
const int _mathBoldLower = 0x1D41A;
const int _mathBoldDigit = 0x1D7CE;

/// Drapeaux émoji : deux indicateurs régionaux forment un code pays.
final RegExp _flagEmoji = RegExp(
  r'([\u{1F1E6}-\u{1F1FF}])([\u{1F1E6}-\u{1F1FF}])',
  unicode: true,
);
const int _regionalIndicatorA = 0x1F1E6;

/// Symboles et émojis employés comme séparateurs décoratifs.
final RegExp _decorations = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2190}-\u{21FF}\u{2500}-\u{27BF}\u{2B00}-\u{2BFF}'
  r'•·«»¦‖]+\u{FE0F}?',
  unicode: true,
);

final RegExp _spaces = RegExp(r'\s+');

/// Remplace les caractères décoratifs par leur équivalent ASCII.
///
/// Les drapeaux deviennent des étiquettes `[FR]`, les autres symboles des
/// séparateurs `|`, ce qui évite de les traiter un par un dans les Regex.
String foldDecorations(String input) {
  final withFlags = input.replaceAllMapped(_flagEmoji, (match) {
    final first = match[1]!.runes.single - _regionalIndicatorA;
    final second = match[2]!.runes.single - _regionalIndicatorA;
    return ' [${_letter(first)}${_letter(second)}] ';
  });
  final buffer = StringBuffer();
  for (final rune in withFlags.replaceAll(_decorations, ' | ').runes) {
    buffer.write(_modifierLetters[rune] ?? _foldMathBold(rune));
  }
  return buffer.toString().replaceAll(_spaces, ' ').trim();
}

String _letter(int offset) => String.fromCharCode(0x41 + offset);

String _foldMathBold(int rune) {
  if (rune >= _mathBoldUpper && rune < _mathBoldUpper + 26) {
    return String.fromCharCode(0x41 + rune - _mathBoldUpper);
  }
  if (rune >= _mathBoldLower && rune < _mathBoldLower + 26) {
    return String.fromCharCode(0x61 + rune - _mathBoldLower);
  }
  if (rune >= _mathBoldDigit && rune < _mathBoldDigit + 10) {
    return String.fromCharCode(0x30 + rune - _mathBoldDigit);
  }
  return String.fromCharCode(rune);
}

const Map<String, String> _diacritics = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ą': 'a',
  'ă': 'a',
  'æ': 'ae',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'đ': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ę': 'e',
  'ě': 'e',
  'ğ': 'g',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ı': 'i',
  'ł': 'l',
  'ñ': 'n',
  'ń': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'œ': 'oe',
  'ř': 'r',
  'ś': 's',
  'š': 's',
  'ş': 's',
  'ș': 's',
  'ß': 'ss',
  'ț': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ů': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
};

final RegExp _diacriticPattern = RegExp('[${_diacritics.keys.join()}]');

/// Met [input] en minuscules et retire les accents latins.
///
/// Les alphabets non latins, comme l'arabe, restent inchangés.
String lowerWithoutDiacritics(String input) => input
    .toLowerCase()
    .replaceAllMapped(_diacriticPattern, (match) => _diacritics[match[0]]!);
