import '../entities/media_segments.dart';

/// Ce qui identifie un épisode auprès des bases d'intros et de génériques.
final class SegmentQuery {
  const SegmentQuery({
    required this.title,
    required this.season,
    required this.episode,
    this.year,
    this.tmdbId,
    this.duration,
  });

  /// Titre de la série, nettoyé.
  final String title;
  final int season;
  final int episode;
  final int? year;

  /// Identifiant TMDb de la série, quand le fournisseur le donne.
  final String? tmdbId;

  /// Durée de la vidéo : elle distingue deux montages d'un même épisode.
  final Duration? duration;
}

/// Bases communautaires des intros et des génériques d'épisodes.
abstract interface class SegmentRepository {
  /// Passages connus pour [query]. [MediaSegments.none] si aucune base n'en
  /// connaît, ou si elles sont injoignables : la lecture n'en dépend pas.
  Future<MediaSegments> find(SegmentQuery query);
}
