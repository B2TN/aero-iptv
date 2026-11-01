import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/http_text_stream.dart';

const String _host = 'api.opensubtitles.com';
const String _basePath = '/api/v1';

/// L'API refuse les agents génériques et impose d'identifier l'application.
const String _userAgent = 'AeroIPTV v0.1';

/// Client de l'API REST d'OpenSubtitles.
final class OpenSubtitlesClient {
  const OpenSubtitlesClient(this._client, {required String apiKey})
    : _apiKey = apiKey;

  final http.Client _client;
  final String _apiKey;

  Map<String, String> get _headers => {
    'Api-Key': _apiKey,
    'User-Agent': _userAgent,
    'Accept': 'application/json',
  };

  /// Retourne le fichier le plus téléchargé pour [query], ou `null`.
  Future<int?> findBestFileId(SubtitleQuery query) async {
    final isEpisode = query.season != null;
    final response = await openGet(
      _client,
      Uri.https(_host, '$_basePath/subtitles', {
        // L'API recommande des paramètres triés par ordre alphabétique.
        if (isEpisode) 'episode_number': '${query.episode ?? 1}',
        'languages': query.language,
        'order_by': 'download_count',
        'order_direction': 'desc',
        'query': query.title.toLowerCase(),
        if (isEpisode) 'season_number': '${query.season}',
        'type': isEpisode ? 'episode' : 'movie',
        if (!isEpisode && query.year != null) 'year': '${query.year}',
      }),
      headers: _headers,
    );
    final json = _decodeObject(await textChunks(response).join());
    final results = json['data'];
    if (results is! List) return null;
    for (final result in results) {
      final fileId = _firstFileId(result);
      if (fileId != null) return fileId;
    }
    return null;
  }

  /// Télécharge le fichier au format SRT.
  ///
  /// Chaque appel consomme le quota journalier du compte : le résultat doit
  /// être conservé par l'appelant.
  Future<String> download(int fileId) async {
    final request =
        http.Request('POST', Uri.https(_host, '$_basePath/download'))
          ..headers.addAll(_headers)
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({'file_id': fileId, 'sub_format': 'srt'});
    final response = await sendRequest(_client, request);
    final json = _decodeObject(await textChunks(response).join());

    // Le lien est temporaire et n'accepte pas la clé d'API.
    final link = Uri.tryParse(json['link']?.toString() ?? '');
    if (link == null || !link.hasScheme) {
      throw const ParseFailure('Lien de téléchargement absent.');
    }
    return textChunks(await openGet(_client, link)).join();
  }

  int? _firstFileId(Object? result) {
    if (result is! Map<String, dynamic>) return null;
    final attributes = result['attributes'];
    if (attributes is! Map<String, dynamic>) return null;
    final files = attributes['files'];
    if (files is! List || files.isEmpty) return null;
    final file = files.first;
    if (file is! Map<String, dynamic>) return null;
    final fileId = file['file_id'];
    return fileId is int ? fileId : int.tryParse('$fileId');
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Traité ci-dessous avec les réponses d'un autre format.
    }
    throw const ParseFailure('Réponse OpenSubtitles illisible.');
  }
}
