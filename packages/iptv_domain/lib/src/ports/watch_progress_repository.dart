import '../entities/watch_progress.dart';

/// Persistance des positions de lecture.
abstract interface class WatchProgressRepository {
  Future<void> save(WatchProgress progress);

  /// Reprises disponibles pour la source, de la plus récente à la plus ancienne.
  Future<List<WatchProgress>> continueWatching(int sourceId, {int limit = 20});

  Future<void> remove(int sourceId, String contentKey);
}
