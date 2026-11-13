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
  int get schemaVersion => 4;

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
    },
  );
}
