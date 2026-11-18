import '../entities/content_kind.dart';
import '../entities/favorite.dart';

/// Favoris de l'utilisateur, par playlist.
abstract interface class FavoritesRepository {
  /// Favoris de la playlist, du plus récent au plus ancien, à chaque changement.
  Stream<List<Favorite>> watch(int sourceId);

  /// Ajoute [favorite], ou rafraîchit son titre et son image s'il y est déjà.
  Future<void> add(Favorite favorite);

  Future<void> remove(int sourceId, ContentKind kind, String key);
}
