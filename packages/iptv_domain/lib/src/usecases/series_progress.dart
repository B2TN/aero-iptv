import '../entities/episode.dart';
import '../entities/season.dart';
import '../entities/watch_progress.dart';
import 'next_episode.dart';

/// Où reprendre une série : un épisode d'une version, et la position.
typedef SeriesResume = ({
  Episode episode,
  Duration position,
  Duration duration,
});

/// Ce qui a été vu d'une série, toutes versions confondues.
final class SeriesProgress {
  /// [history] : les positions des épisodes de la série, la plus récente
  /// d'abord.
  SeriesProgress(this.history)
    : _byEpisode = {
        for (final item in history.reversed)
          if (item.season != null && item.episode != null)
            _order(item.season!, item.episode!): item,
      };

  final List<WatchProgress> history;

  /// Dernière position de chaque épisode, par rang.
  final Map<int, WatchProgress> _byEpisode;

  /// Dernière position de l'épisode, quelle que soit sa version.
  WatchProgress? of(int season, int number) =>
      _byEpisode[_order(season, number)];

  /// Où reprendre dans la version [seasons] : l'épisode le plus avancé, à sa
  /// position ; s'il est fini, l'épisode suivant depuis le début. `null`
  /// sans rien de vu, après le dernier épisode, ou si cette version n'a pas
  /// l'épisode.
  SeriesResume? resumeIn(List<Season> seasons) {
    if (_byEpisode.isEmpty) return null;
    final furthest = _byEpisode.keys.reduce((a, b) => a > b ? a : b);
    final target = _byEpisode[furthest]!;
    final current = [
      for (final season in seasons) ...season.episodes,
    ].where((episode) => _order(episode.season, episode.number) == furthest);
    if (current.isEmpty) return null;
    if (!target.finished) {
      return (
        episode: current.first,
        position: target.position,
        duration: target.duration,
      );
    }
    final following = nextEpisode(seasons, current.first);
    return following == null
        ? null
        : (
            episode: following,
            position: Duration.zero,
            duration: Duration.zero,
          );
  }

  /// Rang d'un épisode dans la série : saison, puis numéro.
  static int _order(int season, int number) => season * 10000 + number;
}
