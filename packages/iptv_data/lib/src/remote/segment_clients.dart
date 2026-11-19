import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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

/// Types d'émissions absents des catalogues de séries des playlists.
const Set<String> _notSeries = {'News', 'Talk Show', 'Sports'};

/// Série lue dans un programme de TVmaze.
typedef _AiringShow = ({int id, String name, int weight});

/// Séries d'un programme de TVmaze, lu hors de l'isolat de l'interface : une
/// journée de programmes pèse plusieurs centaines de kilo-octets, de quoi
/// saccader un stick.
Future<List<_AiringShow>> _airingShowsOf(String body) =>
    Isolate.run(() => _airingShows(body));

List<_AiringShow> _airingShows(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const ParseFailure('Réponse TVmaze illisible.');
  }
  if (decoded is! List) return const [];
  return [for (final entry in decoded) ?_airingShow(entry)];
}

/// Le programme des chaînes donne la série dans `show`, celui des plateformes
/// dans `_embedded.show`.
_AiringShow? _airingShow(Object? entry) {
  if (entry is! Map<String, dynamic>) return null;
  final embedded = entry['_embedded'];
  final show =
      entry['show'] ??
      (embedded is Map<String, dynamic> ? embedded['show'] : null);
  if (show is! Map<String, dynamic> || _notSeries.contains(show['type'])) {
    return null;
  }
  final id = show['id'];
  final name = '${show['name'] ?? ''}'.trim();
  if (id is! int || name.isEmpty) return null;
  final weight = show['weight'];
  return (id: id, name: name, weight: weight is int ? weight : 0);
}

String _isoDay(DateTime day) =>
    '${day.year}-${'${day.month}'.padLeft(2, '0')}-'
    '${'${day.day}'.padLeft(2, '0')}';

/// Client de TVmaze, qui retrouve sans clé les identifiants d'une série.
final class TvMazeClient {
  const TvMazeClient(
    this._client, {
    this.pause = const Duration(milliseconds: 600),
  });

  final http.Client _client;

  /// Attente entre deux demandes d'une série de programmes : TVmaze en
  /// accepte 20 par tranche de 10 secondes.
  final Duration pause;

  /// Séries gardées, des plus populaires.
  static const int _airingLimit = 100;

  /// Séries diffusées les sept derniers jours sur les plateformes et sur les
  /// chaînes américaines, anglaises et de [country], de la plus à la moins
  /// populaire selon TVmaze. Il connaît mal les chaînes de certains pays,
  /// comme la France : les plateformes et les chaînes anglophones, très
  /// présentes dans les playlists, font l'essentiel.
  ///
  /// Un programme qui ne répond pas est passé. Lève une `Failure` si aucun
  /// n'a répondu.
  Future<List<TrendingItem>> airingThisWeek(
    String country, {
    required DateTime now,
  }) async {
    final countries = {'US', 'GB', country.toUpperCase()};
    final schedules = [
      for (var day = 0; day < 7; day++)
        for (final (path, query) in [
          ('/schedule/web', const <String, String>{}),
          for (final code in countries) ('/schedule', {'country': code}),
        ])
          Uri.https('api.tvmaze.com', path, {
            ...query,
            'date': _isoDay(DateTime(now.year, now.month, now.day - day)),
          }),
    ];
    final shows = <int, ({_AiringShow show, int episodes})>{};
    Failure? failure;
    var answered = 0;
    for (final (index, uri) in schedules.indexed) {
      if (index > 0 && pause > Duration.zero) {
        await Future<void>.delayed(pause);
      }
      try {
        final response = await openGet(_client, uri);
        final body = await textChunks(response).join();
        for (final show in await _airingShowsOf(body)) {
          final known = shows[show.id];
          shows[show.id] = (show: show, episodes: (known?.episodes ?? 0) + 1);
        }
        answered++;
      } on Failure catch (error) {
        failure = error;
      }
    }
    if (answered == 0 && failure != null) throw failure;
    // Les plus suivies d'abord ; à égalité, les plus diffusées.
    final ranked = shows.values.toList()
      ..sort(
        (a, b) => switch (b.show.weight.compareTo(a.show.weight)) {
          0 => switch (b.episodes.compareTo(a.episodes)) {
            0 => a.show.name.compareTo(b.show.name),
            final order => order,
          },
          final order => order,
        },
      );
    return [
      for (final entry in ranked.take(_airingLimit))
        TrendingItem(
          kind: ContentKind.series,
          title: entry.show.name,
          originalTitle: entry.show.name,
        ),
    ];
  }

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
    final ended = DateTime.tryParse('${show['ended'] ?? ''}');
    final since = now.subtract(lateWindow);
    // Une série finie depuis longtemps n'annonce plus rien et ne peut plus
    // être en retard : inutile de lire ses épisodes.
    if (!running && (ended == null || ended.isBefore(since))) {
      return const ShowSchedule(running: false);
    }

    final episodes = await _getJson(
      Uri.https('api.tvmaze.com', '/shows/$id/episodes'),
    );
    final upcoming = <UpcomingEpisode>[];
    final aired = <UpcomingEpisode>[];
    if (episodes is List) {
      for (final json in episodes) {
        final parsed = _episode(json);
        if (parsed == null) continue;
        final (episode, stamp) = parsed;
        if (stamp.isAfter(now)) {
          upcoming.add(episode);
        } else if (!stamp.isBefore(since)) {
          aired.add(episode);
        }
      }
    }
    int byDate(UpcomingEpisode a, UpcomingEpisode b) =>
        a.airDate.compareTo(b.airDate);
    return ShowSchedule(
      running: running,
      upcoming: upcoming..sort(byDate),
      aired: aired..sort(byDate),
    );
  }

  /// Retard au-delà duquel un épisode diffusé et absent n'est plus attendu.
  static const Duration lateWindow = Duration(days: 30);

  /// Un épisode et l'instant de sa diffusion, ou `null` s'il manque de quoi
  /// le situer. TVmaze donne l'instant exact (`airstamp`) et le jour dans le
  /// pays d'origine (`airdate`), seul montré.
  static (UpcomingEpisode, DateTime)? _episode(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final season = json['season'];
    final number = json['number'];
    final stamp = DateTime.tryParse('${json['airstamp'] ?? ''}');
    final day = DateTime.tryParse('${json['airdate'] ?? ''}');
    if (season is! int || number is! int || stamp == null || day == null) {
      return null;
    }
    final name = '${json['name'] ?? ''}'.trim();
    final episode = UpcomingEpisode(
      season: season,
      number: number,
      airDate: DateTime(day.year, day.month, day.day),
      // TVmaze nomme « TBA » ou « Episode 5 » un épisode sans titre annoncé.
      title: name.isEmpty || name == 'TBA' || name == 'Episode $number'
          ? null
          : name,
    );
    return (episode, stamp);
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
