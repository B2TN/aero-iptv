/// Empreintes des objets bruts d'une liste Xtream.
///
/// La synchronisation compare l'empreinte d'un objet à celle de la veille :
/// identique, l'objet n'est ni décodé, ni nettoyé, ni écrit. C'est ce qui la
/// rend rapide sur un appareil lent.
library;

const int _fnvOffset = 0xcbf29ce484222325;
const int _fnvPrime = 0x100000001b3;

/// Version de l'empreinte des objets : 2 ne retient que les champs lus.
const int entryHashVersion = 2;

const int _quote = 0x22;
const int _backslash = 0x5C;
const int _comma = 0x2C;
const int _openBrace = 0x7B;
const int _closeBrace = 0x7D;
const int _openBracket = 0x5B;
const int _closeBracket = 0x5D;

/// Préfixe du rang de l'objet dans la liste : il change dès qu'un titre est
/// inséré plus haut, sans que l'objet lui-même change.
const String _numberPrefix = '{"num":';

/// Empreinte FNV-1a sur 64 bits de [text], à partir de [start].
int _fnv(String text, {int start = 0, int seed = _fnvOffset}) {
  var hash = seed;
  for (var i = start; i < text.length; i++) {
    hash = (hash ^ text.codeUnitAt(i)) * _fnvPrime;
  }
  return hash;
}

/// Empreinte des catégories d'une section : un groupe renommé change les
/// entrées qui y sont rangées.
int categoriesHash(Map<String, String> categories) {
  final keys = categories.keys.toList()..sort();
  var hash = _fnvOffset;
  for (final key in keys) {
    hash = _fnv(key, seed: hash);
    hash = _fnv(categories[key]!, seed: hash);
  }
  return hash;
}

/// Empreinte des seuls champs [fields] d'un objet brut, mêlée à celle de ses
/// catégories. Un champ que l'application ne lit pas, comme une note que le
/// panneau recalcule chaque jour, ne fait pas passer l'objet pour modifié :
/// sans cela, toute la liste serait retraitée chaque jour.
///
/// Un objet qui ne se lit pas comme attendu garde l'empreinte de tout son
/// texte.
int rawFieldsHash(String raw, Set<String> fields, int categories) {
  final seed = categories ^ _fnvOffset;
  var hash = seed;
  var i = raw.indexOf('{') + 1;
  if (i == 0) return _fnv(raw, seed: seed);
  while (i < raw.length) {
    final unit = raw.codeUnitAt(i);
    if (unit == _closeBrace) return hash;
    if (unit != _quote) {
      i++;
      continue;
    }
    final keyEnd = _stringEnd(raw, i);
    final key = raw.substring(i + 1, keyEnd);
    final colon = raw.indexOf(':', keyEnd);
    if (colon < 0) return _fnv(raw, seed: seed);
    var start = colon + 1;
    while (start < raw.length && raw.codeUnitAt(start) <= 0x20) {
      start++;
    }
    final end = _valueEnd(raw, start);
    if (fields.contains(key)) {
      hash = _fnv(key, seed: hash);
      hash = _fnvRange(raw, start, end, hash);
    }
    i = end;
  }
  return hash;
}

int _fnvRange(String text, int start, int end, int seed) {
  var hash = seed;
  for (var i = start; i < end; i++) {
    hash = (hash ^ text.codeUnitAt(i)) * _fnvPrime;
  }
  return hash;
}

/// Index du guillemet qui ferme la chaîne ouverte en [open].
int _stringEnd(String raw, int open) {
  var i = open + 1;
  while (i < raw.length) {
    final unit = raw.codeUnitAt(i);
    if (unit == _backslash) {
      i += 2;
    } else if (unit == _quote) {
      return i;
    } else {
      i++;
    }
  }
  return raw.length;
}

/// Fin, exclue, de la valeur qui commence en [start] : une chaîne, un objet,
/// une liste, ou un nombre, un booléen, `null`.
int _valueEnd(String raw, int start) {
  if (start >= raw.length) return raw.length;
  final first = raw.codeUnitAt(start);
  if (first == _quote) return _stringEnd(raw, start) + 1;
  if (first == _openBrace || first == _openBracket) {
    var depth = 0;
    var i = start;
    while (i < raw.length) {
      final unit = raw.codeUnitAt(i);
      if (unit == _quote) {
        i = _stringEnd(raw, i) + 1;
        continue;
      }
      if (unit == _openBrace || unit == _openBracket) depth++;
      if (unit == _closeBrace || unit == _closeBracket) {
        depth--;
        if (depth == 0) return i + 1;
      }
      i++;
    }
    return raw.length;
  }
  var i = start;
  while (i < raw.length) {
    final unit = raw.codeUnitAt(i);
    if (unit == _comma || unit == _closeBrace) return i;
    i++;
  }
  return raw.length;
}

/// Empreinte de tout le texte d'un objet brut, sans son rang dans la liste,
/// mêlée à celle de ses catégories : celle de la version 1, que la
/// synchronisation de transition compare encore.
int rawEntryHash(String raw, int categories) {
  var start = 0;
  if (raw.startsWith(_numberPrefix)) {
    final comma = raw.indexOf(',', _numberPrefix.length);
    if (comma > 0) start = comma + 1;
  }
  return _fnv(raw, start: start, seed: categories ^ _fnvOffset);
}

/// Valeur entière du champ [field] d'un objet brut (`"stream_id":123` ou
/// `"stream_id":"123"`), sans décoder l'objet ; `null` si elle manque.
int? rawEntryId(String raw, String field) {
  final key = raw.indexOf('"$field"');
  if (key < 0) return null;
  var i = raw.indexOf(':', key + field.length + 2);
  if (i < 0) return null;
  i++;
  while (i < raw.length) {
    final unit = raw.codeUnitAt(i);
    if (unit != 0x20 && unit != 0x22) break;
    i++;
  }
  var value = 0;
  var digits = 0;
  while (i < raw.length) {
    final unit = raw.codeUnitAt(i);
    if (unit < 0x30 || unit > 0x39) break;
    value = value * 10 + unit - 0x30;
    digits++;
    i++;
  }
  return digits == 0 ? null : value;
}
