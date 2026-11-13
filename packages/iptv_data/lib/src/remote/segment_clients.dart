import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/http_text_stream.dart';

/// Lit un objet JSON, ou lève [ParseFailure].
Map<String, dynamic> _object(String body, String service) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // Traité ci-dessous avec les réponses d'un autre format.
  }
  throw ParseFailure('Réponse $service illisible.');
}

Duration? _milliseconds(Object? value) => switch (value) {
  final int ms => Duration(milliseconds: ms),
  final double ms => Duration(milliseconds: ms.round()),
  _ => null,
};

/// Client de TheIntroDB, base communautaire des intros et des génériques.
///
/// Lecture sans clé, limitée à 30 requêtes par 10 secondes et 5000 par jour
/// et par adresse IP.
final class TheIntroDbClient {
  const TheIntroDbClient(this._client);

  final http.Client _client;

  /// Passages d'un épisode. Un seul identifiant est envoyé : TheIntroDB les
  /// classe de lui-même, TheTVDB d'abord.
  Future<MediaSegments> episode({
    required int season,
    required int episode,
    String? tmdbId,
    int? tvdbId,
    Duration? duration,
  }) async {
    final id = tvdbId != null
        ? {'tvdb_id': '$tvdbId'}
        : tmdbId != null
        ? {'tmdb_id': tmdbId}
        : null;
    if (id == null) return MediaSegments.none;
    final uri = Uri.https('api.theintrodb.org', '/v4/media', {
      ...id,
      'season': '$season',
      'episode': '$episode',
      if (duration != null && duration > Duration.zero)
        'duration_ms': '${duration.inMilliseconds}',
    });
    final http.StreamedResponse response;
    try {
      response = await openGet(_client, uri);
    } on ServerFailure catch (failure) {
      // Épisode ou série inconnus de la base.
      if (failure.status == HttpStatus.notFound) return MediaSegments.none;
      rethrow;
    }
    final json = _object(await textChunks(response).join(), 'TheIntroDB');
    return MediaSegments(
      intro: _span(json['intro'], openStart: true),
      credits: _span(json['credits'], openStart: false),
    );
  }

  /// Premier passage d'une liste `[{start_ms, end_ms}]`. Un début `null` vaut
  /// le début de la vidéo, une fin `null` sa fin.
  SegmentSpan? _span(Object? value, {required bool openStart}) {
    if (value is! List || value.isEmpty) return null;
    final first = value.first;
    if (first is! Map<String, dynamic>) return null;
    final start =
        _milliseconds(first['start_ms']) ?? (openStart ? Duration.zero : null);
    if (start == null) return null;
    return SegmentSpan(start, _milliseconds(first['end_ms']));
  }
}

/// Client d'IntroDB, base communautaire des intros et des génériques.
///
/// Lecture sans clé ni compte. Données sous licence ODbL 1.0.
final class IntroDbClient {
  const IntroDbClient(this._client);

  final http.Client _client;

  /// Passages d'un épisode, identifié par l'identifiant IMDb de sa série.
  Future<MediaSegments> episode({
    required String imdbId,
    required int season,
    required int episode,
  }) async {
    final uri = Uri.https('api.introdb.app', '/segments', {
      'imdb_id': imdbId,
      'season': '$season',
      'episode': '$episode',
    });
    final response = await openGet(_client, uri);
    final json = _object(await textChunks(response).join(), 'IntroDB');
    return MediaSegments(
      intro: _span(json['intro']),
      credits: _span(json['outro']),
    );
  }

  SegmentSpan? _span(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final start = _milliseconds(value['start_ms']);
    if (start == null) return null;
    return SegmentSpan(start, _milliseconds(value['end_ms']));
  }
}

/// Identifiants d'une série dans les autres bases.
typedef SeriesIds = ({int? tvdbId, String? imdbId});

/// Client de TVmaze, qui retrouve sans clé les identifiants d'une série.
final class TvMazeClient {
  const TvMazeClient(this._client);

  final http.Client _client;

  /// Série dont le nom est exactement [title], et, si [year] est connue, dont
  /// la diffusion a commencé cette année-là. `null` si aucune ne correspond :
  /// une série voisine donnerait des passages faux.
  Future<SeriesIds?> lookup(String title, {int? year}) async {
    final show = await _findShow(title, year: year);
    final externals = show?['externals'];
    if (externals is! Map<String, dynamic>) return null;
    final tvdb = externals['thetvdb'];
    final imdb = externals['imdb'];
    return (
      tvdbId: tvdb is int ? tvdb : null,
      imdbId: imdb is String && imdb.startsWith('tt') ? imdb : null,
    );
  }

  /// État de diffusion de la série et ses prochains épisodes, à partir de
  /// [now]. `null` si aucune série ne correspond, comme pour [lookup].
  Future<ShowSchedule?> schedule(
    String title, {
    int? year,
    required DateTime now,
  }) async {
    final show = await _findShow(title, year: year);
    final id = show?['id'];
    if (show == null || id is! int) return null;
    final running = show['status'] == 'Running';
    // Une série terminée n'annonce plus rien : inutile de lire ses épisodes.
    if (!running) return const ShowSchedule(running: false);

    final episodes = await _getJson(
      Uri.https('api.tvmaze.com', '/shows/$id/episodes'),
    );
    final upcoming = <UpcomingEpisode>[
      if (episodes is List)
        for (final episode in episodes) ?_upcoming(episode, now),
    ]..sort((a, b) => a.airDate.compareTo(b.airDate));
    return ShowSchedule(running: true, upcoming: upcoming);
  }

  /// Épisode pas encore diffusé à [now], ou `null`. TVmaze donne l'instant
  /// exact de diffusion (`airstamp`) et le jour dans le pays d'origine
  /// (`airdate`), seul montré.
  static UpcomingEpisode? _upcoming(Object? json, DateTime now) {
    if (json is! Map<String, dynamic>) return null;
    final season = json['season'];
    final number = json['number'];
    final stamp = DateTime.tryParse('${json['airstamp'] ?? ''}');
    final day = DateTime.tryParse('${json['airdate'] ?? ''}');
    if (season is! int || number is! int || stamp == null || day == null) {
      return null;
    }
    if (!stamp.isAfter(now)) return null;
    final name = '${json['name'] ?? ''}'.trim();
    return UpcomingEpisode(
      season: season,
      number: number,
      airDate: DateTime(day.year, day.month, day.day),
      // TVmaze nomme « TBA » ou « Episode 5 » un épisode sans titre annoncé.
      title: name.isEmpty || name == 'TBA' || name == 'Episode $number'
          ? null
          : name,
    );
  }

  /// Série dont le nom est exactement [title], et, si [year] est connue, dont
  /// la diffusion a commencé cette année-là.
  Future<Map<String, dynamic>?> _findShow(String title, {int? year}) async {
    final decoded = await _getJson(
      Uri.https('api.tvmaze.com', '/search/shows', {'q': title}),
    );
    if (decoded is! List) return null;
    final wanted = GroupingKey.of(title);
    for (final result in decoded) {
      if (result is! Map<String, dynamic>) continue;
      final show = result['show'];
      if (show is! Map<String, dynamic>) continue;
      if (GroupingKey.of('${show['name'] ?? ''}') != wanted) continue;
      final premiered = '${show['premiered'] ?? ''}';
      if (year != null && !premiered.startsWith('$year')) continue;
      return show;
    }
    return null;
  }

  Future<Object?> _getJson(Uri uri) async {
    final response = await openGet(_client, uri);
    try {
      return jsonDecode(await textChunks(response).join());
    } on FormatException {
      throw const ParseFailure('Réponse TVmaze illisible.');
    }
  }
}
