import '../common/failure.dart';
import '../entities/import_progress.dart';
import '../entities/playlist_source.dart';
import '../ports/catalog_importer.dart';
import '../ports/credential_store.dart';

/// Synchronise une source avec les identifiants du coffre.
final class ImportPlaylist {
  const ImportPlaylist(this._credentials, this._importer);

  final CredentialStore _credentials;
  final CatalogImporter _importer;

  Stream<ImportProgress> call(PlaylistSource source) async* {
    final credentials = await _credentials.read(source.id);
    if (credentials == null) {
      throw const AuthFailure('Identifiants absents du coffre.');
    }
    yield* _importer.run(source, credentials);
  }
}
