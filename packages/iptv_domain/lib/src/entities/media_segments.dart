/// Durée la plus longue admise pour une intro. Au-delà, la donnée décrit autre
/// chose, ou un autre montage de la vidéo.
const Duration _longestIntro = Duration(minutes: 5);

/// Passage d'une vidéo : son intro, ou son générique de fin.
final class SegmentSpan {
  const SegmentSpan(this.start, [this.end]);

  final Duration start;

  /// `null` : le passage va jusqu'à la fin de la vidéo.
  final Duration? end;

  /// Fin du passage dans une vidéo de [duration].
  Duration endIn(Duration duration) => end ?? duration;

  bool contains(Duration position, Duration duration) =>
      position >= start && position < endIn(duration);
}

/// Chapitre déclaré dans le fichier vidéo.
final class MediaChapter {
  const MediaChapter({required this.title, required this.start});

  final String title;
  final Duration start;
}

/// Intro et générique de fin d'une vidéo, quand une source les connaît.
///
/// Un passage inconnu vaut `null` : aucun bouton ne s'affiche alors à une
/// position devinée.
final class MediaSegments {
  const MediaSegments({this.intro, this.credits});

  static const MediaSegments none = MediaSegments();

  final SegmentSpan? intro;
  final SegmentSpan? credits;

  bool get isEmpty => intro == null && credits == null;
  bool get isComplete => intro != null && credits != null;

  /// Complète les passages inconnus avec ceux de [other].
  MediaSegments orElse(MediaSegments other) => MediaSegments(
    intro: intro ?? other.intro,
    credits: credits ?? other.credits,
  );

  /// Écarte les passages impossibles dans une vidéo de [duration] : une base
  /// communautaire peut décrire un autre montage que celui du fournisseur.
  ///
  /// Une intro a une fin, se trouve dans la première moitié et dure moins de
  /// cinq minutes. Un générique commence dans la seconde moitié.
  MediaSegments fittedTo(Duration duration) {
    if (duration <= Duration.zero) return none;
    final half = duration ~/ 2;
    final intro = this.intro;
    final introEnd = intro?.end;
    final keepsIntro =
        intro != null &&
        introEnd != null &&
        intro.start >= Duration.zero &&
        introEnd > intro.start &&
        introEnd <= duration &&
        intro.start < half &&
        introEnd - intro.start <= _longestIntro;
    final credits = this.credits;
    final creditsEnd = credits?.end;
    final keepsCredits =
        credits != null &&
        credits.start >= half &&
        credits.start < duration &&
        (creditsEnd == null || creditsEnd > credits.start);
    return MediaSegments(
      intro: keepsIntro ? intro : null,
      credits: keepsCredits
          ? SegmentSpan(
              credits.start,
              creditsEnd == null || creditsEnd >= duration ? null : creditsEnd,
            )
          : null,
    );
  }
}
