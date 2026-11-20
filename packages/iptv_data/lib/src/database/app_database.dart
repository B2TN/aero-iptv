import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Base locale de l'application.
///
/// Les tables et les requêtes vivent dans les fichiers `.drift` : le générateur
/// vérifie leur SQL à la compilation.
@DriftDatabase(
  include: {
    'tables/catalog.drift',
    'tables/epg.drift',
    'tables/trending.drift',
    'tables/user_state.drift',
  },
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 12;

  /// Retrouve, dans le catalogue actif, l'identité commune aux versions des
  /// reprises enregistrées avant qu'elle n'existe. Une reprise dont le
  /// contenu a quitté le catalogue reste seule.
  Future<void> _identifyProgress() async {
    const episodeOf = '''
      FROM episodes e
      JOIN series_entries s ON s.id = e.series_entry_id
      WHERE e.content_key = watch_progress.content_key
        AND e.catalog_id = (SELECT active_catalog_id FROM sources
                            WHERE id = watch_progress.source_id)
      LIMIT 1''';
    await customStatement('''
      UPDATE watch_progress SET
        series_key = (SELECT s.grouping_key $episodeOf),
        season = (SELECT e.season $episodeOf),
        episode = (SELECT e.number $episodeOf)
      WHERE kind = 2''');
    await customStatement('''
      UPDATE watch_progress
      SET work_key = 'e:' || series_key || ':' || season || ':' || episode
      WHERE kind = 2 AND series_key IS NOT NULL''');
    await customStatement('''
      UPDATE watch_progress SET work_key = 'm:' || (
        SELECT m.title_key FROM movies m
        WHERE m.content_key = watch_progress.content_key
          AND m.catalog_id = (SELECT active_catalog_id FROM sources
                              WHERE id = watch_progress.source_id)
        LIMIT 1)
      WHERE kind = 1''');
  }

  /// Rattache les favoris et les positions de lecture aux fiches du
  /// catalogue affiché, après un regroupement qui a pu les changer : chacun
  /// suit sa version, retrouvée par sa clé de contenu. Ce qui a quitté le
  /// catalogue garde sa clé.
  ///
  /// Les listes observées à l'écran ne sont prévenues que si une ligne a
  /// bougé : la synchronisation quotidienne n'en change presque jamais.
  Future<void> refreshUserKeys() async {
    const shownOf = '(SELECT active_catalog_id FROM sources WHERE id = ';
    var favoritesMoved = 0;
    var progressMoved = 0;
    Future<int> write(String sql) => customUpdate(sql);
    // Un favori sans témoin en reçoit un : la première version de sa fiche.
    await write('''
      UPDATE favorites SET content_key = CASE kind
        WHEN 1 THEN (
          SELECT m.content_key FROM movies m
          WHERE m.catalog_id = ${shownOf}favorites.source_id)
            AND m.grouping_key = favorites.favorite_key
          ORDER BY m.sort_order LIMIT 1)
        ELSE (
          SELECT NULLIF(s.entry_key, '') FROM series_entries s
          WHERE s.catalog_id = ${shownOf}favorites.source_id)
            AND s.grouping_key = favorites.favorite_key
          ORDER BY s.sort_order LIMIT 1)
      END
      WHERE content_key IS NULL AND kind IN (1, 2)''');
    for (final (kind, table, key) in [
      (1, 'movies', 'content_key'),
      (2, 'series_entries', 'entry_key'),
    ]) {
      // La version témoin du favori [f], dans une autre fiche que la sienne.
      String moved(String f) =>
          '''
        t.catalog_id = $shownOf$f.source_id)
        AND t.$key = $f.content_key AND t.grouping_key <> $f.favorite_key''';
      // Le favori passe à sa nouvelle fiche ; s'il y retrouve un autre favori,
      // les deux n'en font plus qu'un.
      favoritesMoved += await write('''
        INSERT OR IGNORE INTO favorites (source_id, kind, favorite_key, title,
          poster_url, added_at, content_key)
        SELECT f.source_id, f.kind, t.grouping_key, f.title, f.poster_url,
               f.added_at, f.content_key
        FROM favorites f JOIN $table t ON ${moved('f')}
        WHERE f.kind = $kind''');
      favoritesMoved += await write('''
        DELETE FROM favorites WHERE kind = $kind AND EXISTS (
          SELECT 1 FROM $table t WHERE ${moved('favorites')})''');
    }
    progressMoved += await write('''
      UPDATE watch_progress SET work_key = 'm:' || (
        SELECT m.grouping_key FROM movies m
        WHERE m.catalog_id = ${shownOf}watch_progress.source_id)
          AND m.content_key = watch_progress.content_key
        LIMIT 1)
      WHERE kind = 1 AND EXISTS (
        SELECT 1 FROM movies m
        WHERE m.catalog_id = ${shownOf}watch_progress.source_id)
          AND m.content_key = watch_progress.content_key
          AND 'm:' || m.grouping_key IS NOT watch_progress.work_key)''');
    const seriesOf =
        '''
      FROM episodes e JOIN series_entries s ON s.id = e.series_entry_id
      WHERE e.catalog_id = ${shownOf}watch_progress.source_id)
        AND e.content_key = watch_progress.content_key''';
    progressMoved += await write(
      '''
      UPDATE watch_progress SET series_key = (
        SELECT s.grouping_key $seriesOf LIMIT 1)
      WHERE kind = 2 AND EXISTS (
        SELECT 1 $seriesOf AND s.grouping_key IS NOT watch_progress.series_key)''',
    );
    progressMoved += await write('''
      UPDATE watch_progress
      SET work_key = 'e:' || series_key || ':' || season || ':' || episode
      WHERE kind = 2 AND series_key IS NOT NULL AND season IS NOT NULL
        AND episode IS NOT NULL
        AND work_key IS NOT
            'e:' || series_key || ':' || season || ':' || episode''');
    notifyUpdates({
      if (favoritesMoved > 0) TableUpdate.onTable(favorites),
      if (progressMoved > 0) TableUpdate.onTable(watchProgress),
    });
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(seriesEntries, seriesEntries.tmdbId);
      }
      if (from < 3) {
        // Sous-titres téléchargés d'OpenSubtitles, service retiré.
        await migrator.deleteTable('subtitle_cache');
      }
      if (from < 4) {
        // Résumés, genres et durées des films, des séries et des épisodes.
        for (final table in <TableInfo<Table, Object?>>[
          movies,
          seriesEntries,
        ]) {
          for (final name in [
            'overview',
            'genre',
            'runtime_minutes',
            'details_loaded',
          ]) {
            await migrator.addColumn(table, table.columnsByName[name]!);
          }
        }
        await migrator.addColumn(episodes, episodes.overview);
      }
      if (from < 5) {
        await migrator.createTable(favorites);
      }
      if (from < 6) {
        for (final column in [
          watchProgress.workKey,
          watchProgress.seriesKey,
          watchProgress.season,
          watchProgress.episode,
          watchProgress.finished,
          watchProgress.hidden,
        ]) {
          await migrator.addColumn(watchProgress, column);
        }
        await _identifyProgress();
      }
      if (from < 7) {
        // Identité des versions de séries et date de modification Xtream :
        // la synchronisation quotidienne compare le catalogue à ses
        // prédécesseurs. Le réimport qu'entraîne `catalogRulesVersion` les
        // remplit.
        await migrator.addColumn(seriesEntries, seriesEntries.entryKey);
        await migrator.addColumn(seriesEntries, seriesEntries.lastModified);
        await migrator.createIndex(moviesContent);
        await migrator.createIndex(seriesEntryKey);
        await migrator.createIndex(episodesContent);
        // Les lignes de l'index de recherche prennent un numéro tiré du
        // titre, que les anciennes pourraient déjà occuper. Le réimport le
        // reconstruit.
        await customStatement('DELETE FROM search_index');
      }
      if (from < 8) {
        // Rang dans la numérotation nationale : la prochaine
        // synchronisation, qui remplace les chaînes, le remplit.
        await migrator.addColumn(liveChannels, liveChannels.nationalRank);
      }
      if (from < 9) {
        // Empreintes des objets du fournisseur : vides, la prochaine
        // synchronisation traite tout, puis ne traite que les changements.
        await migrator.addColumn(movies, movies.sourceHash);
        await migrator.addColumn(seriesEntries, seriesEntries.sourceHash);
        await migrator.addColumn(sources, sources.liveHash);
      }
      if (from < 10) {
        // Fiches des films, regroupées comme celles des séries. En attendant
        // le réimport qu'entraîne `catalogRulesVersion`, chaque fiche est
        // celle du titre : les clés des favoris et des reprises restent
        // valables, et ce réimport les déplacera vers les nouvelles fiches.
        await migrator.addColumn(movies, movies.groupingKey);
        await migrator.addColumn(movies, movies.tmdbId);
        await migrator.addColumn(movies, movies.quality);
        await customStatement('UPDATE movies SET grouping_key = title_key');
        await migrator.createIndex(moviesGroup);
        // Avant la version 5, la table vient d'être créée, colonne comprise.
        if (from >= 5) {
          await migrator.addColumn(favorites, favorites.contentKey);
        }
        await refreshUserKeys();
      }
      if (from < 11) {
        // Tendances gardées d'une actualisation à l'autre.
        await migrator.createTable(trendingTitles);
      }
      if (from < 12) {
        // Version des empreintes : celles déjà enregistrées sont de la 1.
        await migrator.addColumn(sources, sources.hashVersion);
      }
    },
  );
}
