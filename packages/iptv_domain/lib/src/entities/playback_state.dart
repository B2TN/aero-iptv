import 'media_track.dart';

/// Phase de la lecture.
enum PlaybackStatus { idle, opening, buffering, playing, paused, ended, failed }

/// État du lecteur.
///
/// Les messages bruts de mpv ne sortent jamais du moteur : ils citent l'URL du
/// flux, donc les identifiants de l'abonné. [failureDetail] en est expurgé.
final class PlaybackState {
  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.tracksReady = false,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.selectedAudioId,
    this.selectedSubtitleId,
    this.failureDetail,
  });

  final PlaybackStatus status;
  final Duration position;
  final Duration duration;

  /// Les pistes du flux sont connues, ce qui permet de choisir les sous-titres.
  final bool tracksReady;
  final List<MediaTrack> audioTracks;
  final List<MediaTrack> subtitleTracks;
  final String? selectedAudioId;
  final String? selectedSubtitleId;

  /// Motif technique d'un échec, sans URL ni identifiant.
  final String? failureDetail;

  PlaybackState copyWith({
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    bool? tracksReady,
    List<MediaTrack>? audioTracks,
    List<MediaTrack>? subtitleTracks,
    String? selectedAudioId,
    String? selectedSubtitleId,
    String? failureDetail,
  }) => PlaybackState(
    status: status ?? this.status,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    tracksReady: tracksReady ?? this.tracksReady,
    audioTracks: audioTracks ?? this.audioTracks,
    subtitleTracks: subtitleTracks ?? this.subtitleTracks,
    selectedAudioId: selectedAudioId ?? this.selectedAudioId,
    selectedSubtitleId: selectedSubtitleId ?? this.selectedSubtitleId,
    failureDetail: failureDetail ?? this.failureDetail,
  );
}
