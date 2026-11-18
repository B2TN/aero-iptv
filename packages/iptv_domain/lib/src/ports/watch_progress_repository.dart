import '../entities/watch_progress.dart';

/// Persistance des positions de lecture.
abstract interface class WatchProgressRepository {
  /// Enregistre une position. Une reprise retirée de « Continuer à regarder »
  /// y revient dès qu'on la relit.
  Future<void> save(WatchProgress progress);

  /// Reprises en cours, ni finies ni retirées, de la plus récente à la plus
  /// ancienne.
  Future<List<WatchProgress>> continueWatching(int sourceId, {int limit = 20});

  /// Reprises en cours et finies, hors retirées, de la plus récente à la plus
  /// ancienne : de quoi composer « Continuer à regarder ».
  Future<List<WatchProgress>> history(int sourceId, {int limit = 500});

  /// Positions d'une œuvre dans toutes ses versions, ou de tous les épisodes
  /// d'une série : [key] est une clé d'œuvre (voir [WorkKeys]) ou une clé de
  /// série. Les reprises retirées de « Continuer à regarder » comptent : ce
  /// qui a été vu le reste. De la plus récente à la plus ancienne.
  Future<List<WatchProgress>> progressOf(int sourceId, String key);

  /// Retire de « Continuer à regarder » les reprises de [groupKey] (voir
  /// [WatchProgress.groupKey]), sans oublier ce qui a été vu.
  Future<void> hide(int sourceId, String groupKey);

  Future<void> remove(int sourceId, String contentKey);
}
