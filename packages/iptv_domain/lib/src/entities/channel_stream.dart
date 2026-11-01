import 'stream_locator.dart';
import 'stream_quality.dart';

/// Flux d'une chaîne, proposé dans le menu de choix de qualité.
final class ChannelStream {
  const ChannelStream({
    required this.id,
    required this.quality,
    required this.label,
    required this.locator,
  });

  final int id;
  final StreamQuality quality;

  /// Libellé du menu, par exemple « FHD HEVC ». Peut être vide.
  final String label;
  final StreamLocator locator;
}
