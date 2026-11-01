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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(seriesEntries, seriesEntries.tmdbId);
          }
        },
      );
}
