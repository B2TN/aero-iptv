import '../entities/app_release.dart';

/// Versions publiées de l'application.
abstract interface class ReleaseRepository {
  /// Releases publiées, préversions comprises, brouillons exclus. Lève une
  /// `Failure` si le service ne répond pas.
  Future<List<AppRelease>> releases();
}
