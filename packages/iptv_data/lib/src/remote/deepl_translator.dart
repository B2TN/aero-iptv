import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/http_text_stream.dart';

const int _batchSize = 50;
const Duration _timeout = Duration(seconds: 60);

/// Les clés gratuites se terminent ainsi et ont leur propre adresse.
const String _freeKeySuffix = ':fx';

/// Codes de DeepL différents du code de langue : l'anglais et le portugais
/// demandent une variante, le norvégien s'écrit `NB`.
const Map<String, String> _targetCodes = {
  'en': 'EN-GB',
  'pt': 'PT-PT',
  'no': 'NB',
};

final RegExp _blankLine = RegExp(r'\r?\n\s*\r?\n');
final RegExp _lineBreak = RegExp(r'\r?\n');

/// Une réplique SRT : tout ce qui précède le texte reste inchangé.
final class _Cue {
  const _Cue(this.header, this.text);

  final String header;
  final String text;
}

/// Traduit des sous-titres SRT avec DeepL.
final class DeepLSubtitleTranslator implements SubtitleTranslator {
  const DeepLSubtitleTranslator(this._client, {required String apiKey})
    : _apiKey = apiKey;

  final http.Client _client;
  final String _apiKey;

  Uri get _endpoint => Uri.https(
    _apiKey.endsWith(_freeKeySuffix) ? 'api-free.deepl.com' : 'api.deepl.com',
    '/v2/translate',
  );

  @override
  Future<List<String>> translateTexts(
    List<String> texts, {
    required String language,
  }) => _translateBatch(texts, language);

  @override
  Future<SubtitleFile> translate(
    SubtitleFile file, {
    required String language,
  }) async {
    final cues = [
      for (final block in file.content.trim().split(_blankLine))
        ?_parseCue(block),
    ];
    final translated = <String>[];
    for (var start = 0; start < cues.length; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, cues.length);
      translated.addAll(
        await _translateBatch([
          for (final cue in cues.sublist(start, end)) cue.text,
        ], language),
      );
    }
    final content = [
      for (final (index, cue) in cues.indexed)
        '${cue.header}\n${translated[index]}',
    ].join('\n\n');
    return SubtitleFile(
      content: '$content\n',
      language: language,
      title: file.title,
    );
  }

  /// Retourne `null` pour un bloc qui ne suit pas la forme d'une réplique.
  _Cue? _parseCue(String block) {
    final lines = block.split(_lineBreak);
    final timing = lines.indexWhere((line) => line.contains('-->'));
    if (timing < 0 || timing == lines.length - 1) return null;
    return _Cue(
      lines.sublist(0, timing + 1).join('\n'),
      lines.sublist(timing + 1).join('\n'),
    );
  }

  Future<List<String>> _translateBatch(
    List<String> texts,
    String language,
  ) async {
    final request = http.Request('POST', _endpoint)
      ..headers.addAll({
        'Authorization': 'DeepL-Auth-Key $_apiKey',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'text': texts,
        'target_lang': _targetCodes[language] ?? language.toUpperCase(),
        'preserve_formatting': true,
      });
    final response = await sendRequest(_client, request, timeout: _timeout);
    final Object? json;
    try {
      json = jsonDecode(await textChunks(response).join());
    } on FormatException {
      throw const ParseFailure('Réponse DeepL illisible.');
    }
    final items = json is Map<String, dynamic> ? json['translations'] : null;
    if (items is! List || items.length != texts.length) {
      throw const ParseFailure('Traduction DeepL incomplète.');
    }
    return [
      for (final item in items)
        item is Map<String, dynamic> && item['text'] is String
            ? item['text'] as String
            : throw const ParseFailure('Traduction DeepL illisible.'),
    ];
  }
}
