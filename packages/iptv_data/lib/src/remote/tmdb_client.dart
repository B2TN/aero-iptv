import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/http_text_stream.dart';

const String _host = 'api.themoviedb.org';
const String _posterBase = 'https://image.tmdb.org/t/p/w342';
const String _backdropBase = 'https://image.tmdb.org/t/p/w780';

/// Client de l'API TMDb.
final class TmdbClient {
  const TmdbClient(this._client, {required String readToken})
    : _readToken = readToken;

  final http.Client _client;
  final String _readToken;

  /// Retourne les contenus populaires. `region` n'existe que pour les films.
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    required String language,
    String? region,
  }) async {
    final isMovie = kind == ContentKind.movie;
    final response = await openGet(
      _client,
      Uri.https(_host, '/3/${isMovie ? 'movie' : 'tv'}/popular', {
        'language': language,
        if (isMovie && region != null) 'region': region,
      }),
      headers: {
        'Authorization': 'Bearer $_readToken',
        'Accept': 'application/json',
      },
    );
    final Object? json;
    try {
      json = jsonDecode(await textChunks(response).join());
    } on FormatException {
      throw const ParseFailure('Réponse TMDb illisible.');
    }
    final results = json is Map<String, dynamic> ? json['results'] : null;
    if (results is! List) return const [];
    return [
      for (final result in results)
        if (result is Map<String, dynamic>) ?_toItem(result, kind),
    ];
  }

  TrendingItem? _toItem(Map<String, dynamic> json, ContentKind kind) {
    final isMovie = kind == ContentKind.movie;
    final title = json[isMovie ? 'title' : 'name'];
    final original = json[isMovie ? 'original_title' : 'original_name'];
    if (title is! String || title.isEmpty) return null;
    return TrendingItem(
      kind: kind,
      title: title,
      originalTitle: original is String ? original : title,
      overview: _nonEmpty(json['overview']),
      posterUrl: _imageUrl(_posterBase, json['poster_path']),
      backdropUrl: _imageUrl(_backdropBase, json['backdrop_path']),
    );
  }

  String? _imageUrl(String base, Object? path) =>
      path is String && path.isNotEmpty ? '$base$path' : null;

  String? _nonEmpty(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
