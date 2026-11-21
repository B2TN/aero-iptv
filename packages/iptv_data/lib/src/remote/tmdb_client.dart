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

  /// Image large du titre de [kind] nommé [title], sorti en [year] si elle est
  /// connue. Seul le premier résultat compte : le suivant serait un autre
  /// titre, et son image tromperait.
  Future<String?> backdrop(
    ContentKind kind,
    String title, {
    int? year,
    required String language,
  }) async {
    final isMovie = kind == ContentKind.movie;
    final results = await _get('/3/search/${isMovie ? 'movie' : 'tv'}', {
      'query': title,
      'language': language,
      'include_adult': 'false',
      if (year != null) isMovie ? 'year' : 'first_air_date_year': '$year',
    });
    final first = results.firstOrNull;
    return first == null
        ? null
        : _imageUrl(_backdropBase, first['backdrop_path']);
  }

  /// Identifiant de la série nommée [title], d'après le premier résultat.
  Future<int?> seriesId(String title, {int? year}) async {
    final results = await _get('/3/search/tv', {
      'query': title,
      'include_adult': 'false',
      'first_air_date_year': ?year?.toString(),
    });
    final id = results.firstOrNull?['id'];
    return id is int ? id : null;
  }

  /// Résumés des épisodes de la saison [season] de la série [seriesId], par
  /// numéro d'épisode, dans [language]. TMDB laisse vide le résumé d'un
  /// épisode qu'il n'a pas dans cette langue : celui-là n'y figure pas.
  Future<Map<int, String>> seasonOverviews(
    int seriesId,
    int season, {
    required String language,
  }) async {
    final json = await _object('/3/tv/$seriesId/season/$season', {
      'language': language,
    });
    final episodes = json?['episodes'];
    if (episodes is! List) return const {};
    return {
      for (final episode in episodes.whereType<Map<String, dynamic>>())
        if (episode['episode_number'] case final int number)
          if (_nonEmpty(episode['overview']) case final overview?)
            number: overview,
    };
  }

  Future<List<_Result>> _results(
    ContentKind kind,
    String path,
    Map<String, String> query,
  ) async => [
    for (final result in await _get(path, query)) ?_toResult(result, kind),
  ];

  /// Résultats d'une requête de l'API.
  Future<List<Map<String, dynamic>>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final results = (await _object(path, query))?['results'];
    if (results is! List) return const [];
    return results.whereType<Map<String, dynamic>>().toList();
  }

  /// Réponse d'une requête de l'API, `null` si ce n'est pas un objet.
  Future<Map<String, dynamic>?> _object(
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
    return json is Map<String, dynamic> ? json : null;
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
