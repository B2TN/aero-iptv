import '../common/failure.dart';
import '../entities/continue_row.dart';
import '../entities/show_schedule.dart';
import '../ports/schedule_repository.dart';

/// Prochain épisode des séries à jour, d'après le calendrier de diffusion.
final class AnnouncedEpisodes {
  const AnnouncedEpisodes(this._schedule);

  final ScheduleRepository _schedule;

  /// L'épisode qui suit le dernier vu de chaque série de [series], par clé de
  /// groupe (`WatchProgress.groupKey`) : déjà diffusé mais pas encore dans la
  /// playlist, ou annoncé. Une série terminée, sans suite annoncée ou que le
  /// calendrier ne connaît pas n'y figure pas, pas plus que si le calendrier
  /// est injoignable.
  Future<Map<String, UpcomingEpisode>> call(List<CaughtUpSeries> series) async {
    final next = await Future.wait([for (final item in series) _next(item)]);
    return {
      for (final (index, item) in series.indexed)
        item.progress.groupKey: ?next[index],
    };
  }

  Future<UpcomingEpisode?> _next(CaughtUpSeries caughtUp) async {
    final ShowSchedule? schedule;
    try {
      schedule = await _schedule.scheduleOf(
        caughtUp.series.title,
        year: caughtUp.series.year,
      );
    } on Failure {
      return null;
    }
    if (schedule == null) return null;
    final last = caughtUp.progress;
    final watched = (last.season ?? 0) * 10000 + (last.episode ?? 0);
    // Les diffusés, du plus ancien au plus récent, puis les annoncés.
    return [
      ...schedule.aired,
      ...schedule.upcoming,
    ].where((episode) => episode.order > watched).firstOrNull;
  }
}
