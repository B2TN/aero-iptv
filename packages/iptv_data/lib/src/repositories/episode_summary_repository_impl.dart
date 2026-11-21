import 'package:iptv_domain/iptv_domain.dart';

import '../remote/segment_clients.dart';
import '../remote/tmdb_client.dart';

/// Langue de repli des résumés.
const String _english = 'en';

/// Résumés d'épisodes cherchés sur TMDB dans la langue de l'application, puis
/// en anglais ; sur TVmaze, en anglais, quand TMDB ne décrit pas la saison ou
/// dans les versions sans clé TMDB.
///
/// Chaque saison n'est demandée qu'une fois par session : un épisode qu'aucune
/// base ne décrit est redemandé à la session suivante, car TMDB complète
/// souvent ses résumés quelques jours après la diffusion.
final class EpisodeSummaryRepositoryImpl implements EpisodeSummaryRepository {
  EpisodeSummaryRepositoryImpl({TmdbClient? tmdb, TvMazeClient? tvMaze})
    : _tmdb = tmdb,
      _tvMaze = tvMaze;

  final TmdbClient? _tmdb;
  final TvMazeClient? _tvMaze;
  final Map<String, Future<Map<int, String>>> _found = {};

  @override
  Future<Map<int, String>> seasonSummaries({
    required String title,
    int? year,
    String? tmdbId,
    required int season,
    required String language,
  }) {
    if (title.trim().isEmpty) return Future.value(const {});
    final key =
        '${tmdbId ?? ''}|${lowerWithoutDiacritics(title)}|$year|$season|'
        '$language';
    return _found[key] ??= _search(
      key,
      title: title,
      year: year,
      tmdbId: int.tryParse(tmdbId?.trim() ?? ''),
      season: season,
      language: language,
    );
  }

  Future<Map<int, String>> _search(
    String key, {
    required String title,
    required int? year,
    required int? tmdbId,
    required int season,
    required String language,
  }) async {
    try {
      final found = <int, String>{};
      final tmdb = _tmdb;
      if (tmdb != null) {
        // Les panneaux renvoient « 0 » quand ils ne savent pas.
        final id = tmdbId != null && tmdbId > 0
            ? tmdbId
            : await tmdb.seriesId(title, year: year);
        if (id != null) {
          found.addAll(
            await _orNothing(
              tmdb.seasonOverviews(id, season, language: language),
            ),
          );
          if (language != _english) {
            final english = await _orNothing(
              tmdb.seasonOverviews(id, season, language: _english),
            );
            for (final MapEntry(key: number, value: text) in english.entries) {
              found.putIfAbsent(number, () => text);
            }
          }
        }
      }
      final tvMaze = _tvMaze;
      if (tvMaze != null && (found.isEmpty || tmdb == null)) {
        final english = await tvMaze.seasonSummaries(
          title,
          year: year,
          season: season,
        );
        for (final MapEntry(key: number, value: text) in english.entries) {
          found.putIfAbsent(number, () => text);
        }
      }
      return found;
    } on Failure {
      // Sans réseau : la prochaine ouverture de la fiche réessaiera.
      _found.remove(key);
      return const {};
    }
  }

  /// Une saison que TMDB ne connaît pas répond 404 : ce n'est pas une panne.
  Future<Map<int, String>> _orNothing(Future<Map<int, String>> request) async {
    try {
      return await request;
    } on ServerFailure {
      return const {};
    }
  }
}
