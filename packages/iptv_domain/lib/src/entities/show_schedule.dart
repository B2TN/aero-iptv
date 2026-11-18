import 'season.dart';

/// Épisode annoncé par la chaîne, diffusé ou non.
final class UpcomingEpisode {
  const UpcomingEpisode({
    required this.season,
    required this.number,
    required this.airDate,
    this.title,
  });

  final int season;
  final int number;

  /// Jour de première diffusion dans le pays d'origine, sans heure. L'épisode
  /// arrive chez le fournisseur un peu plus tard.
  final DateTime airDate;

  /// `null` tant que la chaîne ne l'a pas annoncé.
  final String? title;

  /// Rang dans la série : saison, puis numéro.
  int get order => season * 10000 + number;
}

/// État de diffusion d'une série.
final class ShowSchedule {
  const ShowSchedule({
    required this.running,
    this.upcoming = const [],
    this.aired = const [],
  });

  /// Vrai tant que de nouveaux épisodes sont produits.
  final bool running;

  /// Prochains épisodes, du plus proche au plus lointain.
  final List<UpcomingEpisode> upcoming;

  /// Épisodes diffusés depuis peu, du plus ancien au plus récent : ceux que
  /// le fournisseur devrait déjà avoir.
  final List<UpcomingEpisode> aired;

  /// Épisodes diffusés que la playlist n'a pas encore : ceux qui suivent le
  /// dernier de ses [seasons]. Un épisode plus ancien qui manque n'est pas en
  /// retard, le fournisseur ne l'a simplement jamais eu.
  ///
  /// Un épisode plus d'une saison après la dernière de la playlist n'est pas
  /// compté : la playlist numérote alors autrement que TVmaze (numérotation
  /// absolue d'un anime, par exemple) et la comparaison ne dit rien.
  List<UpcomingEpisode> lateAfter(List<Season> seasons) {
    var last = 0;
    for (final season in seasons) {
      for (final episode in season.episodes) {
        final order = episode.season * 10000 + episode.number;
        if (order > last) last = order;
      }
    }
    if (last == 0) return const [];
    final lastSeason = last ~/ 10000;
    return [
      for (final episode in aired)
        if (episode.order > last && episode.season <= lastSeason + 1) episode,
    ];
  }
}
