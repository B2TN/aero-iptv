import 'content_kind.dart';
import 'stream_locator.dart';

/// Position de lecture, affichée dans la rangée « Continuer à regarder ».
final class WatchProgress {
  const WatchProgress({
    required this.sourceId,
    required this.contentKey,
    required this.kind,
    required this.title,
    required this.position,
    required this.duration,
    required this.updatedAt,
    required this.locator,
    this.posterUrl,
  });

  final int sourceId;

  /// Identité stable : elle survit au remplacement du catalogue.
  final String contentKey;
  final ContentKind kind;
  final String title;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  /// Permet de reprendre la lecture sans chercher le contenu dans le catalogue.
  final StreamLocator locator;
  final String? posterUrl;
}
