/// Attribut d'une ligne `#EXTINF` : `clé="valeur"`, `clé='valeur'` ou `clé=valeur`.
final RegExp _attribute = RegExp(
  r'''([A-Za-z][\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s,"']+))''',
);

/// Option `#EXTVLCOPT` portant un en-tête HTTP.
final RegExp _vlcHeader = RegExp(
  r'^#EXTVLCOPT:\s*http-(user-agent|referrer|referer)\s*=\s*(.+)$',
  caseSensitive: false,
);

/// En-têtes ajoutés à l'URL : `http://...|User-Agent=x&Referer=y`.
final RegExp _pipeHeader = RegExp(
  r'(?:^|&)(user-agent|referer|referrer)=([^&]*)',
  caseSensitive: false,
);

/// Attributs de l'en-tête `#EXTM3U` qui annoncent un guide XMLTV.
const List<String> _epgHeaderAttributes = ['url-tvg', 'x-tvg-url', 'tvg-url'];

/// Entrée complète d'une playlist M3U.
final class M3uEntry {
  const M3uEntry({
    required this.title,
    required this.url,
    required this.attributes,
    this.group,
    this.userAgent,
    this.referrer,
  });

  final String title;
  final String url;

  /// Attributs de `#EXTINF`, avec leurs clés en minuscules.
  final Map<String, String> attributes;

  /// Groupe déclaré par `group-title` ou `#EXTGRP`.
  final String? group;
  final String? userAgent;
  final String? referrer;
}

/// Lit une playlist M3U ligne par ligne, sans en conserver le contenu.
///
/// L'analyseur ne garde que l'entrée en cours : sa mémoire reste constante,
/// quelle que soit la taille du fichier.
final class M3uLineParser {
  /// Guide XMLTV annoncé par l'en-tête de la playlist.
  String? epgUrl;

  /// Vrai dès qu'une ligne `#EXTM3U` ou `#EXTINF` a été rencontrée.
  bool sawPlaylistContent = false;

  String? _title;
  Map<String, String> _attributes = const {};
  String? _group;
  String? _userAgent;
  String? _referrer;

  /// Traite une ligne et retourne une entrée lorsque celle-ci est complète.
  M3uEntry? accept(String rawLine) {
    final line = _stripBom(rawLine).trim();
    if (line.isEmpty) return null;
    if (line.startsWith('#EXTM3U')) {
      sawPlaylistContent = true;
      _readHeader(line);
      return null;
    }
    if (line.startsWith('#EXTINF:')) {
      sawPlaylistContent = true;
      _readExtInf(line.substring('#EXTINF:'.length));
      return null;
    }
    if (line.startsWith('#EXTGRP:')) {
      _group = line.substring('#EXTGRP:'.length).trim();
      return null;
    }
    if (line.startsWith('#')) {
      _readVlcOption(line);
      return null;
    }
    return _complete(line);
  }

  String _stripBom(String line) =>
      line.startsWith('﻿') ? line.substring(1) : line;

  void _readHeader(String line) {
    final attributes = _parseAttributes(line);
    epgUrl = _epgHeaderAttributes
        .map((name) => attributes[name])
        .firstWhere((url) => url != null && url.isNotEmpty, orElse: () => null);
  }

  void _readExtInf(String content) {
    final comma = _titleSeparator(content);
    _title = comma < 0 ? '' : content.substring(comma + 1).trim();
    _attributes = _parseAttributes(
      comma < 0 ? content : content.substring(0, comma),
    );
    final group = _attributes['group-title'];
    if (group != null && group.isNotEmpty) _group = group;
  }

  /// Cherche la virgule qui précède le titre, hors des valeurs entre
  /// guillemets. Un guillemet non fermé se rabat sur la dernière virgule.
  int _titleSeparator(String content) {
    var inQuotes = false;
    for (var i = 0; i < content.length; i++) {
      final char = content[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        return i;
      }
    }
    return content.lastIndexOf(',');
  }

  Map<String, String> _parseAttributes(String text) => {
    for (final match in _attribute.allMatches(text))
      match[1]!.toLowerCase(): (match[2] ?? match[3] ?? match[4]!).trim(),
  };

  void _readVlcOption(String line) {
    final match = _vlcHeader.firstMatch(line);
    if (match == null) return;
    final value = match[2]!.trim();
    if (match[1]!.toLowerCase() == 'user-agent') {
      _userAgent = value;
    } else {
      _referrer = value;
    }
  }

  M3uEntry? _complete(String line) {
    final title = _title;
    if (title == null) {
      _reset();
      return null;
    }
    final separator = line.indexOf('|');
    final url = separator < 0 ? line : line.substring(0, separator);
    if (separator >= 0) {
      for (final match in _pipeHeader.allMatches(
        line.substring(separator + 1),
      )) {
        final value = Uri.decodeQueryComponent(match[2]!);
        if (match[1]!.toLowerCase() == 'user-agent') {
          _userAgent = value;
        } else {
          _referrer = value;
        }
      }
    }
    final entry = M3uEntry(
      title: title,
      url: url,
      attributes: _attributes,
      group: _group,
      userAgent: _userAgent,
      referrer: _referrer,
    );
    _reset();
    return entry;
  }

  void _reset() {
    _title = null;
    _attributes = const {};
    _group = null;
    _userAgent = null;
    _referrer = null;
  }
}
