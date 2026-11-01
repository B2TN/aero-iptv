/// Nature d'une piste.
enum MediaTrackKind { audio, subtitle }

/// Piste audio ou de sous-titres d'un flux.
final class MediaTrack {
  const MediaTrack({
    required this.id,
    required this.kind,
    this.title,
    this.language,
    this.codec,
    this.channelCount,
  });

  final String id;
  final MediaTrackKind kind;
  final String? title;

  /// Langue déclarée par le flux, dans le format de celui-ci (`fre`, `fr`...).
  final String? language;
  final String? codec;

  /// Nombre de canaux d'une piste audio, s'il est connu.
  final int? channelCount;
}
