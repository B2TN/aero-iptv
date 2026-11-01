import 'content_kind.dart';
import 'stream_locator.dart';

/// Retard maximal proposé pour les chaînes en direct.
const int maxLiveDelaySeconds = 30;

/// Demande d'ouverture adressée au lecteur.
final class PlaybackRequest {
  const PlaybackRequest({
    required this.stream,
    required this.isLive,
    this.liveDelaySeconds = 0,
    this.startAt,
  });

  final ResolvedStream stream;
  final bool isLive;

  /// Secondes mises en réserve avant de démarrer une chaîne en direct.
  final int liveDelaySeconds;

  /// Position de reprise d'un film ou d'un épisode.
  final Duration? startAt;
}

/// Contenu lu, pour la reprise de lecture et la recherche de sous-titres.
final class PlaybackItem {
  const PlaybackItem({
    required this.sourceId,
    required this.contentKey,
    required this.title,
    required this.kind,
    required this.locator,
    this.posterUrl,
    this.year,
    this.season,
    this.episode,
  });

  final int sourceId;
  final String contentKey;
  final String title;
  final ContentKind kind;
  final StreamLocator locator;
  final String? posterUrl;
  final int? year;
  final int? season;
  final int? episode;
}
