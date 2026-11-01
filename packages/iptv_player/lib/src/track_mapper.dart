import 'package:iptv_domain/iptv_domain.dart';
import 'package:media_kit/media_kit.dart' as mk;

/// Traduit les pistes de media_kit vers le domaine.
abstract final class TrackMapper {
  /// Pistes audio réelles, sans les entrées techniques `auto` et `no`.
  static List<MediaTrack> audio(Iterable<mk.AudioTrack> tracks) => [
    for (final track in tracks.where(isRealAudio))
      MediaTrack(
        id: track.id,
        kind: MediaTrackKind.audio,
        title: track.title,
        language: track.language,
        codec: track.codec,
        channelCount: track.audiochannels ?? track.channelscount,
      ),
  ];

  /// Pistes de sous-titres réelles, sans les entrées techniques `auto` et `no`.
  static List<MediaTrack> subtitle(Iterable<mk.SubtitleTrack> tracks) => [
    for (final track in tracks.where(isRealSubtitle))
      MediaTrack(
        id: track.id,
        kind: MediaTrackKind.subtitle,
        title: track.title,
        language: track.language,
        codec: track.codec,
      ),
  ];

  static bool isRealAudio(mk.AudioTrack track) => _isReal(track.id);

  static bool isRealSubtitle(mk.SubtitleTrack track) => _isReal(track.id);

  static bool _isReal(String id) => id != 'auto' && id != 'no';
}
