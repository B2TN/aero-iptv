import 'package:iptv_domain/iptv_domain.dart';

import '../remote/segment_clients.dart';

/// Durée pendant laquelle un calendrier reste valable : les chaînes annoncent
/// rarement un épisode moins d'un jour à l'avance.
const Duration _freshFor = Duration(hours: 6);

/// Séries gardées en mémoire, pour revenir sur une fiche sans attendre.
const int _cachedShows = 100;

/// Calendrier de diffusion des séries, d'après TVmaze.
final class ScheduleRepositoryImpl implements ScheduleRepository {
  ScheduleRepositoryImpl(this._tvMaze, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TvMazeClient _tvMaze;
  final DateTime Function() _clock;
  final Map<String, ({DateTime at, ShowSchedule? schedule})> _cache = {};

  @override
  Future<ShowSchedule?> scheduleOf(String title, {int? year}) async {
    final key = '${GroupingKey.of(title)}|${year ?? ''}';
    final now = _clock();
    final cached = _cache[key];
    if (cached != null && now.difference(cached.at) < _freshFor) {
      return cached.schedule;
    }
    final schedule = await _tvMaze.schedule(title, year: year, now: now);
    if (_cache.length >= _cachedShows) _cache.remove(_cache.keys.first);
    _cache[key] = (at: now, schedule: schedule);
    return schedule;
  }
}
