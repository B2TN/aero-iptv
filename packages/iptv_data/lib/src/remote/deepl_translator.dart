import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/http_text_stream.dart';

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

/// Traduit des répliques de sous-titres avec DeepL.
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
