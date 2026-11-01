import 'episode.dart';

/// Saison d'une version de série.
final class Season {
  const Season({required this.number, required this.episodes});

  final int number;
  final List<Episode> episodes;
}
