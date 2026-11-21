import '../entities/import_pause.dart';
import '../entities/import_progress.dart';
import '../entities/playlist_source.dart';

/// Remplit le catalogue local d'une source.
abstract interface class CatalogImporter {
  /// Lance la synchronisation hors de l'isolate d'interface.
  ///
  /// Le catalogue précédent reste consultable jusqu'au dernier moment : une
  /// erreur laisse donc l'application dans son état d'origine. Le flux se
  /// termine par une erreur de type [Failure] si rien n'a pu être importé. Une
  /// section seule en échec n'arrête pas les autres : elle est signalée par
  /// [ImportProgress.failedSections].
  ///
  /// Un catalogue déjà affiché ne reçoit que ses différences avec celui qui
  /// arrive ; [full] le remplace en entier.
  ///
  /// Tant que [pause] le demande, la synchronisation attend sans rien
  /// télécharger : un téléchargement coupé reprend ensuite du début.
  Stream<ImportProgress> run(
    PlaylistSource source,
    PlaylistCredentials credentials, {
    bool full = false,
    ImportPause? pause,
  });
}
