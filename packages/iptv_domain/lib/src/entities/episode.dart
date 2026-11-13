import 'stream_locator.dart';

/// Épisode d'une version de série.
final class Episode {
  const Episode({
    required this.id,
    required this.seriesEntryId,
    required this.season,
    required this.number,
    required this.title,
    required this.contentKey,
    required this.locator,
    this.overview,
  });

  final int id;
  final int seriesEntryId;
  final int season;
  final int number;
  final String title;

  /// Identité stable entre deux synchronisations, contrairement à [id].
  final String contentKey;
  final StreamLocator locator;

  /// Résumé de l'épisode, quand le fournisseur le donne.
  final String? overview;
}
