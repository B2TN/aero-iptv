import '../entities/playlist_source.dart';

/// Coffre des identifiants, implémenté avec le stockage sécurisé du système.
abstract interface class CredentialStore {
  Future<PlaylistCredentials?> read(int sourceId);

  Future<void> write(int sourceId, PlaylistCredentials credentials);

  Future<void> delete(int sourceId);
}
