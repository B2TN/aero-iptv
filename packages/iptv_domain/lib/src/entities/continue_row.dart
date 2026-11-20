import 'series.dart';
import 'watch_progress.dart';

/// Série vue jusqu'au dernier épisode que la playlist propose. Elle reste dans
/// « Continuer à regarder » si la suite est annoncée.
final class CaughtUpSeries {
  const CaughtUpSeries({required this.progress, required this.series});

  /// Le dernier épisode vu, le plus avancé de la série.
  final WatchProgress progress;
  final Series series;
}

/// « Continuer à regarder » : les reprises, et à part les séries à jour.
final class ContinueRow {
  const ContinueRow(this.items, {this.caughtUp = const []});

  /// Une entrée par film ou par série, la plus récente d'abord.
  final List<WatchProgress> items;

  /// Les séries à jour, la plus récente d'abord. Leur place est après
  /// [items], et seulement si leur suite est annoncée.
  final List<CaughtUpSeries> caughtUp;
}
