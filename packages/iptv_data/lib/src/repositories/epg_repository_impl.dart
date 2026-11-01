import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart';

/// Lecture du guide des programmes.
final class EpgRepositoryImpl implements EpgRepository {
  const EpgRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<Map<String, EpgProgramme>> nowPlaying(
    int sourceId,
    Iterable<String> epgKeys,
    DateTime at,
  ) async {
    final keys = epgKeys.toList(growable: false);
    if (keys.isEmpty) return const {};
    final now = at.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final rows = await _db
        .nowPlayingFor(sourceId: sourceId, keys: keys, now: now)
        .get();
    return {
      for (final row in rows)
        row.epgKey: EpgProgramme(
          epgKey: row.epgKey,
          title: row.title,
          description: row.description,
          start: _instant(row.startAt),
          stop: _instant(row.stopAt),
        ),
    };
  }

  DateTime _instant(int seconds) => DateTime.fromMillisecondsSinceEpoch(
    seconds * Duration.millisecondsPerSecond,
    isUtc: true,
  );
}
