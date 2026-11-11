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
const int _colon = 0x3A;
const int _comma = 0x2C;

/// Clés de la réponse de connexion : un panneau la renvoie à la place d'une
/// liste quand il refuse une demande.
const Set<String> _loginKeys = {'user_info', 'server_info'};

/// Une clé plus longue n'est comparée à rien : inutile de la garder.
const int _maxKeyLength = 32;

/// La réponse s'arrête avant la fin de la liste : le serveur a coupé l'envoi.
final class TruncatedJsonException implements Exception {
  const TruncatedJsonException();
}

/// Découpe une liste JSON en objets, sans attendre la fin de la réponse.
///
/// `jsonDecode` construit toute la réponse en mémoire, ce qui représente
/// plusieurs dizaines de Mo pour un catalogue Xtream. Ici, chaque objet est
/// isolé puis décodé seul, et la mémoire reste bornée par le plus grand objet.
final class JsonArraySplitter {
  final StringBuffer _pending = StringBuffer();
  final StringBuffer _key = StringBuffer();
  bool _started = false;
  bool _finished = false;
  bool _inString = false;
  bool _escaped = false;

  /// La liste est un objet indexé : PHP encode ainsi un tableau à trous.
  bool _keyed = false;

  /// Entre le `:` d'une clé et la virgule suivante, une chaîne est une valeur.
  bool _afterColon = false;
  int _keys = 0;
  int _elements = 0;
  int _depth = 0;

  /// Vrai une fois la liste refermée. Faux à la fin de la réponse, elle a été
  /// coupée en route.
  bool get isComplete => _finished;

  /// Traite un fragment et retourne les objets complets qu'il termine.
  ///
  /// Certains serveurs répondent `{}` à la place d'un tableau vide, ou un objet
  /// indexé `{"0": {...}, "2": {...}}` à la place d'un tableau : ses valeurs sont
  /// alors les éléments. Toute autre réponse lève une [FormatException], qu'il
  /// s'agisse d'une page HTML, de la réponse de connexion ou d'un message
  /// d'erreur : les prendre pour une liste vide ferait disparaître une section
  /// entière du catalogue sans rien signaler.
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
          if (_depth == 0) _endTopLevelString();
        } else if (_readingKey && _key.length < _maxKeyLength) {
          _key.writeCharCode(unit);
        }
        continue;
      }
      if (!_started) {
        if (_isWhitespace(unit)) continue;
        if (unit != _openBracket && unit != _openBrace) {
          throw const FormatException('Liste JSON attendue.');
        }
        _started = true;
        _keyed = unit == _openBrace;
        continue;
      }
      if (unit == _quote) {
        _inString = true;
      } else if (unit == _openBrace || unit == _openBracket) {
        if (_depth == 0) start = i;
        _depth++;
      } else if (unit == _closeBrace || unit == _closeBracket) {
        if (_depth == 0) {
          if (_keys > 0 && _elements == 0) {
            throw const FormatException('Objet JSON sans liste.');
          }
          _finished = true;
          continue;
        }
        _depth--;
        if (_depth == 0) {
          _pending.write(chunk.substring(start, i + 1));
          completed.add(_pending.toString());
          _pending.clear();
          _elements++;
          start = -1;
        }
      } else if (_depth == 0 && unit == _colon) {
        _afterColon = true;
      } else if (_depth == 0 && unit == _comma) {
        _afterColon = false;
      }
    }

    if (_depth > 0 && !_finished) _pending.write(chunk.substring(start));
    return completed;
  }

  bool get _readingKey => _keyed && _depth == 0 && !_afterColon;

  void _endTopLevelString() {
    if (!_keyed || _afterColon) return;
    final key = _key.toString();
    _key.clear();
    _keys++;
    if (_loginKeys.contains(key)) {
      throw const FormatException('Réponse de connexion reçue.');
    }
  }

  bool _isWhitespace(int unit) =>
      unit == _space ||
      unit == _lineFeed ||
      unit == _carriageReturn ||
      unit == _tab;
}

/// Décode les objets d'une liste JSON reçue par fragments.
///
/// Lève une [TruncatedJsonException] si la réponse se termine avant la liste :
/// une réponse vide ou coupée ne doit pas passer pour une liste complète.
Stream<Map<String, dynamic>> decodeJsonObjects(Stream<String> chunks) async* {
  final splitter = JsonArraySplitter();
  await for (final chunk in chunks) {
    for (final element in splitter.add(chunk)) {
      final decoded = jsonDecode(element);
      if (decoded is Map<String, dynamic>) yield decoded;
    }
  }
  if (!splitter.isComplete) throw const TruncatedJsonException();
}
