import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/http_text_stream.dart';

const String _host = 'api.themoviedb.org';
const String _posterBase = 'https://image.tmdb.org/t/p/w342';

/// Assez grande pour remplir le haut de l'accueil en 1080p.
const String _backdropBase = 'https://image.tmdb.org/t/p/w1280';

/// Pages de 20 titres lues pour chaque liste.
const int _pages = 2;

/// Titre de TMDB, avec son identifiant pour croiser les listes.
typedef _Result = ({int id, TrendingItem item});

/// Client de l'API TMDb.
final class TmdbClient {
  const TmdbClient(this._client, {required String readToken})
    : _readToken = readToken;

  final http.Client _client;
  final String _readToken;

  /// Tendances du moment dans [region] : les titres qu'on peut y regarder
  /// (abonnement, gratuit, location ou achat), du plus au moins populaire
  /// selon TMDB, ceux de la semaine en tête. Une série doit avoir eu un
  /// épisode récent ; un film, être sorti depuis moins de deux ans.
  ///
  /// [language] est un code ISO 639-1, [region] un code ISO 3166-1.
  Future<List<TrendingItem>> trending(
    ContentKind kind, {
    required String language,
    required String region,
    required DateTime now,
  }) async {
    final isMovie = kind == ContentKind.movie;
    final path = isMovie ? 'movie' : 'tv';
    final since = _day(now.subtract(Duration(days: isMovie ? 2 * 365 : 60)));
    final local = <_Result>[
      for (var page = 1; page <= _pages; page++)
        ...await _results(kind, '/3/discover/$path', {
          'language': language,
          'watch_region': region,
          'with_watch_monetization_types': 'flatrate|free|ads|rent|buy',
          'sort_by': 'popularity.desc',
          if (isMovie)
            'primary_release_date.gte': since
          else
            'air_date.gte': since,
          'page': '$page',
        }),
    ];
    final weekly = <_Result>[
      for (var page = 1; page <= _pages; page++)
        ...await _results(kind, '/3/trending/$path/week', {
          'language': language,
          'page': '$page',
        }),
    ];
    // La semaine d'abord, pour les titres qu'on peut regarder dans le pays ;
    // puis les plus populaires du pays.
    final available = {for (final result in local) result.id};
    final seen = <int>{};
    return [
      for (final result in weekly)
        if (available.contains(result.id) && seen.add(result.id)) result.item,
      for (final result in local)
        if (seen.add(result.id)) result.item,
    ];
  }

  Future<List<_Result>> _results(
    ContentKind kind,
    String path,
    Map<String, String> query,
  ) async {
    final response = await openGet(
      _client,
      Uri.https(_host, path, query),
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
        if (result is Map<String, dynamic>) ?_toResult(result, kind),
    ];
  }

  _Result? _toResult(Map<String, dynamic> json, ContentKind kind) {
    final isMovie = kind == ContentKind.movie;
    final id = json['id'];
    final title = json[isMovie ? 'title' : 'name'];
    final original = json[isMovie ? 'original_title' : 'original_name'];
    if (id is! int || title is! String || title.isEmpty) return null;
    return (
      id: id,
      item: TrendingItem(
        kind: kind,
        title: title,
        originalTitle: original is String ? original : title,
        overview: _nonEmpty(json['overview']),
        posterUrl: _imageUrl(_posterBase, json['poster_path']),
        backdropUrl: _imageUrl(_backdropBase, json['backdrop_path']),
      ),
    );
  }

  static String _day(DateTime day) =>
      '${day.year}-${'${day.month}'.padLeft(2, '0')}-'
      '${'${day.day}'.padLeft(2, '0')}';

  String? _imageUrl(String base, Object? path) =>
      path is String && path.isNotEmpty ? '$base$path' : null;

  String? _nonEmpty(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
