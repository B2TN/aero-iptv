import '../entities/content_kind.dart';

/// Images d'un titre venues d'un service public, pour remplacer celles que la
/// playlist ne donne pas ou qui ne s'affichent pas.
abstract interface class ArtworkRepository {
  /// Image large d'un film ou d'une série, cherchée par son titre et, si elle
  /// est connue, son année. `null` si le service ne la connaît pas, s'il ne
  /// répond pas, ou sans service.
  Future<String?> backdrop(
    ContentKind kind,
    String title, {
    int? year,
    required String language,
  });
}
