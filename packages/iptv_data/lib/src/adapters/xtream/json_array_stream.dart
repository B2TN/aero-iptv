import 'dart:convert';

const int _quote = 0x22;
const int _backslash = 0x5C;
const int _openBracket = 0x5B;
const int _closeBracket = 0x5D;
const int _openBrace = 0x7B;
const int _closeBrace = 0x7D;
const int _space = 0x20;
const int _lineFeed = 0x0A;
const int _carriageReturn = 0x0D;
const int _tab = 0x09;

/// Découpe un tableau JSON en objets, sans attendre la fin de la réponse.
///
/// `jsonDecode` construit toute la réponse en mémoire, ce qui représente
/// plusieurs dizaines de Mo pour un catalogue Xtream. Ici, chaque objet est
/// isolé puis décodé seul, et la mémoire reste bornée par le plus grand objet.
final class JsonArraySplitter {
  final StringBuffer _pending = StringBuffer();
  bool _started = false;
  bool _finished = false;
  bool _inString = false;
  bool _escaped = false;
  int _depth = 0;

  /// Traite un fragment et retourne les objets complets qu'il termine.
  ///
  /// Certains serveurs répondent `{}` à la place d'un tableau vide : ce cas
  /// produit une liste vide. Toute autre réponse, comme une page HTML
  /// d'erreur, lève une [FormatException].
  List<String> add(String chunk) {
    final completed = <String>[];
    var start = _depth > 0 ? 0 : -1;

    for (var i = 0; i < chunk.length && !_finished; i++) {
      final unit = chunk.codeUnitAt(i);
      if (_inString) {
        if (_escaped) {
          _escaped = false;
        } else if (unit == _backslash) {
          _escaped = true;
        } else if (unit == _quote) {
          _inString = false;
        }
        continue;
      }
      if (!_started) {
        if (_isWhitespace(unit)) continue;
        if (unit == _openBracket) {
          _started = true;
          continue;
        }
        if (unit == _openBrace) {
          _finished = true;
          continue;
        }
        throw const FormatException('Tableau JSON attendu.');
      }
      if (unit == _quote) {
        if (_depth > 0) _inString = true;
      } else if (unit == _openBrace || unit == _openBracket) {
        if (_depth == 0) start = i;
        _depth++;
      } else if (unit == _closeBrace || unit == _closeBracket) {
        if (_depth == 0) {
          _finished = true;
          continue;
        }
        _depth--;
        if (_depth == 0) {
          _pending.write(chunk.substring(start, i + 1));
          completed.add(_pending.toString());
          _pending.clear();
          start = -1;
        }
      }
    }

    if (_depth > 0 && !_finished) _pending.write(chunk.substring(start));
    return completed;
  }

  bool _isWhitespace(int unit) =>
      unit == _space ||
      unit == _lineFeed ||
      unit == _carriageReturn ||
      unit == _tab;
}

/// Décode les objets d'un tableau JSON reçu par fragments.
Stream<Map<String, dynamic>> decodeJsonObjects(Stream<String> chunks) async* {
  final splitter = JsonArraySplitter();
  await for (final chunk in chunks) {
    for (final element in splitter.add(chunk)) {
      final decoded = jsonDecode(element);
      if (decoded is Map<String, dynamic>) yield decoded;
    }
  }
}
