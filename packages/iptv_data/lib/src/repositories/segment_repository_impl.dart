import 'package:iptv_domain/iptv_domain.dart';

import '../remote/segment_clients.dart';

/// Réponses gardées en mémoire : de quoi enchaîner une saison sans redemander
/// les identifiants de la série.
const int _cachedEntries = 200;

/// Intros et génériques des bases communautaires, TheIntroDB puis IntroDB.
///
/// Une base injoignable ou qui refuse la requête est passée : la suivante
/// complète ce qu'elle n'a pas donné.
final class SegmentRepositoryImpl implements SegmentRepository {
  SegmentRepositoryImpl({
    required TheIntroDbClient theIntroDb,
    required IntroDbClient introDb,
    required TvMazeClient tvMaze,
  }) : _theIntroDb = theIntroDb,
       _introDb = introDb,
       _tvMaze = tvMaze;

  final TheIntroDbClient _theIntroDb;
  final IntroDbClient _introDb;
  final TvMazeClient _tvMaze;

  final Map<String, MediaSegments> _segments = {};
  final Map<String, SeriesIds?> _ids = {};

  @override
  Future<MediaSegments> find(SegmentQuery query) async {
    final series = '${GroupingKey.of(query.title)}|${query.year}';
    final key = '$series|${query.tmdbId}|${query.season}|${query.episode}';
    final cached = _segments[key];
    if (cached != null) return cached;

    var unreachable = false;
    Future<MediaSegments> attempt(Future<MediaSegments> Function() read) async {
      try {
        return await read();
      } on Failure {
        unreachable = true;
        return MediaSegments.none;
      }
    }

    var found = await attempt(
      () => _theIntroDb.episode(
        tmdbId: query.tmdbId,
        season: query.season,
        episode: query.episode,
        duration: query.duration,
      ),
    );
    if (!found.isComplete) {
      final ids = await _idsOf(series, query);
      final tvdbId = ids?.tvdbId;
      final imdbId = ids?.imdbId;
      // Sans identifiant TMDb, TheIntroDB n'a pas encore été interrogée.
      if (query.tmdbId == null && tvdbId != null) {
        found = found.orElse(
          await attempt(
            () => _theIntroDb.episode(
              tvdbId: tvdbId,
              season: query.season,
              episode: query.episode,
              duration: query.duration,
            ),
          ),
        );
      }
      if (!found.isComplete && imdbId != null) {
        found = found.orElse(
          await attempt(
            () => _introDb.episode(
              imdbId: imdbId,
              season: query.season,
              episode: query.episode,
            ),
          ),
        );
      }
    }
    // Une base injoignable sera de nouveau interrogée au prochain essai.
    if (!unreachable || found.isComplete) _remember(_segments, key, found);
    return found;
  }

  Future<SeriesIds?> _idsOf(String series, SegmentQuery query) async {
    if (_ids.containsKey(series)) return _ids[series];
    try {
      final ids = await _tvMaze.lookup(query.title, year: query.year);
      _remember(_ids, series, ids);
      return ids;
    } on Failure {
      // Non gardé : TVmaze sera de nouveau interrogé à l'épisode suivant.
      return null;
    }
  }

  void _remember<T>(Map<String, T> cache, String key, T value) {
    if (cache.length >= _cachedEntries) cache.remove(cache.keys.first);
    cache[key] = value;
  }
}
