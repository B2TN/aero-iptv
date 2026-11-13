/// Épisode annoncé, pas encore diffusé.
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
}

/// État de diffusion d'une série.
final class ShowSchedule {
  const ShowSchedule({required this.running, this.upcoming = const []});

  /// Vrai tant que de nouveaux épisodes sont produits.
  final bool running;

  /// Prochains épisodes, du plus proche au plus lointain.
  final List<UpcomingEpisode> upcoming;
}
