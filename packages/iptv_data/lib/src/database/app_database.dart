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
    'tables/user_state.drift',
  },
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 6;

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
    },
  );
}
