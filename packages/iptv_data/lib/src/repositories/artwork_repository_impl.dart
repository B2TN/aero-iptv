import 'package:iptv_domain/iptv_domain.dart';

import '../remote/tmdb_client.dart';

/// Images larges cherchées sur TMDB, gardées le temps de la session : rouvrir
/// une fiche ne refait pas la recherche.
final class ArtworkRepositoryImpl implements ArtworkRepository {
  ArtworkRepositoryImpl({TmdbClient? tmdb}) : _tmdb = tmdb;

  final TmdbClient? _tmdb;
  final Map<String, Future<String?>> _found = {};

  @override
  Future<String?> backdrop(
    ContentKind kind,
    String title, {
    int? year,
    required String language,
  }) {
    final tmdb = _tmdb;
    if (tmdb == null || title.trim().isEmpty) return Future.value();
    final key = '${kind.name}|${lowerWithoutDiacritics(title)}|$year';
    return _found[key] ??= _search(tmdb, key, kind, title, year, language);
  }

  Future<String?> _search(
    TmdbClient tmdb,
    String key,
    ContentKind kind,
    String title,
    int? year,
    String language,
  ) async {
    try {
      return await tmdb.backdrop(kind, title, year: year, language: language);
    } on Failure {
      // Sans réseau : une prochaine ouverture réessaiera.
      _found.remove(key);
      return null;
    }
  }
}
