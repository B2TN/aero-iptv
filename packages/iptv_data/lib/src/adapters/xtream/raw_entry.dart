/// Empreintes des objets bruts d'une liste Xtream.
///
/// La synchronisation compare l'empreinte d'un objet à celle de la veille :
/// identique, l'objet n'est ni décodé, ni nettoyé, ni écrit. C'est ce qui la
/// rend rapide sur un appareil lent.
library;

const int _fnvOffset = 0xcbf29ce484222325;
const int _fnvPrime = 0x100000001b3;

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

/// Empreinte d'un objet brut, sans son rang dans la liste, mêlée à celle de
/// ses catégories.
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
