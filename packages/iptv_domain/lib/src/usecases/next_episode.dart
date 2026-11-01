import '../entities/episode.dart';
import '../entities/season.dart';

/// Épisode qui suit [current], dans sa saison ou au début de la suivante.
Episode? nextEpisode(List<Season> seasons, Episode current) {
  final ordered = [...seasons]..sort((a, b) => a.number.compareTo(b.number));
  final episodes = [
    for (final season in ordered)
      ...[...season.episodes]..sort((a, b) => a.number.compareTo(b.number)),
  ];
  final index = episodes.indexWhere(
    (episode) =>
        episode.season == current.season && episode.number == current.number,
  );
  return index < 0 || index + 1 == episodes.length ? null : episodes[index + 1];
}
