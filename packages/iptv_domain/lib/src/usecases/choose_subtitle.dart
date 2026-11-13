import '../entities/media_track.dart';
import '../normalization/language_code.dart';

/// Décision prise une fois les pistes du flux connues.
sealed class SubtitleChoice {
  const SubtitleChoice();
}

/// L'audio est déjà dans la langue voulue.
final class SubtitlesNotNeeded extends SubtitleChoice {
  const SubtitlesNotNeeded();
}

/// Le flux contient déjà des sous-titres dans la langue voulue.
final class UseEmbeddedSubtitles extends SubtitleChoice {
  const UseEmbeddedSubtitles(this.track);

  final MediaTrack track;
}

/// Le flux n'a pas de sous-titres dans la langue voulue. L'utilisateur peut
/// faire traduire une autre piste depuis le lecteur.
final class SubtitlesMissing extends SubtitleChoice {
  const SubtitlesMissing(this.language);

  final String language;
}

/// Applique la règle du cahier des charges sur les sous-titres.
final class ChooseSubtitle {
  const ChooseSubtitle();

  /// [preferredLanguage] est la langue de l'application.
  SubtitleChoice call({
    required List<MediaTrack> audioTracks,
    required List<MediaTrack> subtitleTracks,
    required String preferredLanguage,
    String? selectedAudioId,
  }) {
    final wanted =
        normalizeLanguageCode(preferredLanguage) ?? preferredLanguage;

    final audio = audioTracks
        .where((track) => track.id == selectedAudioId)
        .followedBy(audioTracks)
        .firstOrNull;
    if (normalizeLanguageCode(audio?.language) == wanted) {
      return const SubtitlesNotNeeded();
    }

    for (final track in subtitleTracks) {
      if (normalizeLanguageCode(track.language) == wanted) {
        return UseEmbeddedSubtitles(track);
      }
    }
    return SubtitlesMissing(wanted);
  }
}
