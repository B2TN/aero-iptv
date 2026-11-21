import '../common/failure.dart';
import '../entities/import_pause.dart';
import '../entities/import_progress.dart';
import '../entities/playlist_source.dart';
import '../ports/catalog_importer.dart';
import '../ports/credential_store.dart';

/// Synchronise une source avec les identifiants du coffre.
final class ImportPlaylist {
  const ImportPlaylist(this._credentials, this._importer);

  final CredentialStore _credentials;
  final CatalogImporter _importer;

  /// [full] remplace le catalogue en entier, au lieu de n'appliquer que ses
  /// différences. [pause] la suspend, par exemple pendant une lecture.
  Stream<ImportProgress> call(
    PlaylistSource source, {
    bool full = false,
    ImportPause? pause,
  }) async* {
    final credentials = await _credentials.read(source.id);
    if (credentials == null) {
      throw const AuthFailure('Identifiants absents du coffre.');
    }
    yield* _importer.run(source, credentials, full: full, pause: pause);
  }
}
