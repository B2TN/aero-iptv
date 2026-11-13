import '../entities/media_segments.dart';
import '../entities/media_track.dart';
import '../entities/playback_request.dart';
import '../entities/playback_state.dart';
import '../entities/subtitle_file.dart';

/// Contrat du moteur vidéo.
///
/// L'interface ne connaît que ce contrat : le moteur peut donc être remplacé
/// sans toucher aux écrans.
abstract interface class PlaybackEngine {
  /// État courant.
  PlaybackState get state;

  /// Émet chaque changement d'état. La position est émise une fois par seconde.
  Stream<PlaybackState> get states;

  /// Texte du sous-titre affiché, vide entre deux répliques.
  Stream<String> get subtitleCues;

  /// Ouvre un flux. Peut être rappelé pour changer de chaîne.
  Future<void> open(PlaybackRequest request);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  /// Règle le volume, de 0 à 100.
  Future<void> setVolume(double percent);

  Future<void> selectAudio(MediaTrack track);

  /// Active une piste de sous-titres, ou les désactive si [track] est `null`.
  Future<void> selectSubtitle(MediaTrack? track);

  /// Charge et active des sous-titres externes.
  Future<void> loadSubtitle(SubtitleFile file);

  /// Chapitres déclarés par le fichier en cours, vides s'il n'en a pas. Ils ne
  /// sont connus qu'une fois sa durée connue.
  Future<List<MediaChapter>> chapters();

  /// Libère le moteur. Il ne peut plus être utilisé ensuite.
  Future<void> dispose();
}
