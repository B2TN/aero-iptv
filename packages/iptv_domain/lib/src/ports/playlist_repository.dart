import '../common/result.dart';
import '../entities/playlist_source.dart';

/// Gestionnaire des sources IPTV.
abstract interface class PlaylistRepository {
  /// Émet la liste des sources à chaque modification.
  Stream<List<PlaylistSource>> watchSources();

  Future<Result<PlaylistSource>> add({
    required String name,
    required PlaylistCredentials credentials,
    String? defaultCountryCode,
  });

  /// Met à jour une source. [credentials] à `null` conserve ceux en place.
  Future<Result<void>> update(
    PlaylistSource source, {
    PlaylistCredentials? credentials,
  });

  /// Supprime la source, ses identifiants et tout son catalogue.
  Future<Result<void>> delete(int sourceId);
}
