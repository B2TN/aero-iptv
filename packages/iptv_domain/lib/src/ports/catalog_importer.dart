import '../entities/import_progress.dart';
import '../entities/playlist_source.dart';

/// Remplit le catalogue local d'une source.
abstract interface class CatalogImporter {
  /// Lance la synchronisation hors de l'isolate d'interface.
  ///
  /// Le catalogue précédent reste consultable jusqu'au dernier moment : une
  /// erreur laisse donc l'application dans son état d'origine. Le flux se
  /// termine par une erreur de type [Failure] en cas d'échec.
  Stream<ImportProgress> run(
    PlaylistSource source,
    PlaylistCredentials credentials,
  );
}
