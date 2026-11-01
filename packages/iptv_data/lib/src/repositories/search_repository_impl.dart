import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart';

final RegExp _queryToken = RegExp(r'[\p{L}\p{N}]+', unicode: true);

/// Début de `group_key` dans l'index : `s` pour une série, `m` pour un film.
const String _seriesPrefix = 's';

/// Version d'un titre, telle que la recherche la compare.
final class _Version {
  const _Version(this.id, this.title, this.posterUrl, this.label);

  final int id;
  final String title;
  final String? posterUrl;
  final String? label;
}

/// Recherche plein texte. Ces requêtes sont écrites à la main, car `rank` et
/// `MATCH` sortent de ce que le générateur Drift sait typer.
final class SearchRepositoryImpl implements SearchRepository {
  const SearchRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<String>> suggest(
    int sourceId,
    String input, {
    int limit = 8,
  }) async {
    final match = toFtsPrefixQuery(input);
    if (match == null) return const [];
    final rows = await _db
        .customSelect(
          '''
          SELECT MIN(title) AS title, MIN(rank) AS score
          FROM search_index
          WHERE search_index MATCH ?1
            AND catalog_id = (SELECT active_catalog_id FROM sources WHERE id = ?2)
          GROUP BY group_key
          ORDER BY score
          LIMIT ?3
          ''',
          variables: [
            Variable.withString(match),
            Variable.withInt(sourceId),
            Variable.withInt(limit),
          ],
        )
        .get();
    return [for (final row in rows) row.read<String>('title')];
  }

  @override
  Future<Page<SearchHit>> search(
    int sourceId,
    String query,
    PageRequest page, {
    required String language,
  }) async {
    final match = toFtsPrefixQuery(query);
    if (match == null) return Page(items: const [], request: page);
    final rows = await _db
        .customSelect(
          '''
          SELECT group_key, kind, MIN(ref_id) AS ref_id, MIN(title) AS title,
                 MAX(poster_url) AS poster_url, MIN(rank) AS score
          FROM search_index
          WHERE search_index MATCH ?1
            AND catalog_id = (SELECT active_catalog_id FROM sources WHERE id = ?2)
          GROUP BY group_key
          ORDER BY score
          LIMIT ?3 OFFSET ?4
          ''',
          variables: [
            Variable.withString(match),
            Variable.withInt(sourceId),
            Variable.withInt(page.limit),
            Variable.withInt(page.offset),
          ],
        )
        .get();
    final seriesKeys = <String>[];
    final movieKeys = <String>[];
    for (final row in rows) {
      final key = row.read<String>('group_key');
      (key.startsWith(_seriesPrefix) ? seriesKeys : movieKeys).add(
        key.substring(1),
      );
    }
    final series = await _bestSeries(sourceId, seriesKeys, language);
    final movies = await _bestMovies(sourceId, movieKeys, language);
    return Page(
      items: [for (final row in rows) _hit(row, series, movies)],
      request: page,
    );
  }

  /// Titre et affiche de la meilleure version. L'index ne connaît pas la langue,
  /// et un groupe mêle toutes les traductions d'un titre.
  SearchHit _hit(
    QueryRow row,
    Map<String, _Version> series,
    Map<String, _Version> movies,
  ) {
    final key = row.read<String>('group_key');
    final kind = ContentKind.values[row.read<int>('kind')];
    final name = key.substring(1);
    final best = (key.startsWith(_seriesPrefix) ? series : movies)[name];
    return SearchHit(
      kind: kind,
      id: best?.id ?? row.read<int>('ref_id'),
      title: best?.title ?? row.read<String>('title'),
      posterUrl: best?.posterUrl ?? row.readNullable<String>('poster_url'),
    );
  }

  Future<Map<String, _Version>> _bestSeries(
    int sourceId,
    List<String> keys,
    String language,
  ) async {
    if (keys.isEmpty) return const {};
    final rows = await _db
        .versionsOfSeriesKeys(sourceId: sourceId, keys: keys)
        .get();
    final versions = <String, List<_Version>>{};
    for (final row in rows) {
      (versions[row.groupingKey] ??= []).add(
        _Version(row.id, row.displayTitle, row.posterUrl, row.languageTag),
      );
    }
    return {
      for (final entry in versions.entries)
        entry.key: _pick(entry.value, language),
    };
  }

  Future<Map<String, _Version>> _bestMovies(
    int sourceId,
    List<String> keys,
    String language,
  ) async {
    if (keys.isEmpty) return const {};
    final rows = await _db
        .moviesWithTitleKeys(sourceId: sourceId, keys: keys)
        .get();
    final versions = <String, List<_Version>>{};
    for (final row in rows) {
      (versions[row.titleKey] ??= []).add(
        _Version(row.id, row.displayTitle, row.posterUrl, row.languageTag),
      );
    }
    return {
      for (final entry in versions.entries)
        entry.key: _pick(entry.value, language),
    };
  }

  /// La version la mieux classée, avec la première affiche disponible.
  _Version _pick(List<_Version> versions, String language) {
    final ranked = versionsByLanguage(
      versions,
      (version) => version.label,
      language,
    );
    final best = ranked.first;
    return _Version(
      best.id,
      best.title,
      ranked.map((version) => version.posterUrl).nonNulls.firstOrNull,
      best.label,
    );
  }

  /// Convertit la saisie en requête FTS5.
  ///
  /// Chaque mot est mis entre guillemets : un caractère réservé tapé au clavier
  /// virtuel, comme `-` ou `*`, ne peut donc pas provoquer d'erreur de syntaxe.
  /// Retourne `null` si la saisie ne contient ni lettre ni chiffre.
  static String? toFtsPrefixQuery(String input) {
    final tokens = _queryToken.allMatches(input).map((match) => match[0]!);
    if (tokens.isEmpty) return null;
    return tokens.map((token) => '"$token"*').join(' ');
  }
}
