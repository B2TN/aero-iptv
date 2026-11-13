import '../common/failure.dart';
import '../entities/media_segments.dart';
import '../normalization/text_folding.dart';
import '../ports/playback_engine.dart';
import '../ports/segment_repository.dart';

/// Chapitres d'intro, en anglais et en français, une fois les accents retirés.
final RegExp _introTitle = RegExp(
  r'^(intro|introduction|opening|opening (credits|theme|titles|song)|op|'
  r'title sequence|main titles?|generique de debut|generique d ouverture|'
  r'ouverture)$',
);

/// Chapitres de générique de fin.
final RegExp _creditsTitle = RegExp(
  r'^(end credits|ending|ending (credits|theme|song)|ed|outro|closing|'
  r'closing credits|end titles|generique de fin|generique final)$',
);

/// Titres qui désignent l'un ou l'autre selon leur place dans la vidéo.
final RegExp _ambiguousTitle = RegExp(r'^(credits|generique)$');

final RegExp _separators = RegExp(r'[^a-z0-9]+');

String _normalized(String title) =>
    lowerWithoutDiacritics(title).replaceAll(_separators, ' ').trim();

/// Intro et générique de fin déclarés par les chapitres du fichier.
MediaSegments segmentsFromChapters(
  List<MediaChapter> chapters,
  Duration duration,
) {
  final sorted = [...chapters]..sort((a, b) => a.start.compareTo(b.start));
  SegmentSpan? intro;
  SegmentSpan? credits;
  for (final (index, chapter) in sorted.indexed) {
    final next = index + 1 < sorted.length ? sorted[index + 1].start : null;
    final title = _normalized(chapter.title);
    final firstHalf = chapter.start < duration ~/ 2;
    final isIntro =
        _introTitle.hasMatch(title) ||
        (_ambiguousTitle.hasMatch(title) && firstHalf);
    final isCredits =
        _creditsTitle.hasMatch(title) ||
        (_ambiguousTitle.hasMatch(title) && !firstHalf);
    if (isIntro && intro == null) {
      intro = SegmentSpan(chapter.start, next ?? duration);
    } else if (isCredits && credits == null) {
      credits = SegmentSpan(chapter.start, next);
    }
  }
  return MediaSegments(intro: intro, credits: credits);
}

/// Cherche l'intro et le générique d'une vidéo en cours de lecture.
///
/// Les chapitres du fichier passent en premier : ils décrivent exactement ce
/// montage. Les bases communautaires complètent ce qu'ils ne disent pas.
final class FindMediaSegments {
  const FindMediaSegments(this._remote);

  /// `null` si aucune base communautaire n'est consultée.
  final SegmentRepository? _remote;

  /// [query] est `null` pour une vidéo que les bases ne savent pas identifier,
  /// comme un film : seuls ses chapitres comptent alors.
  Future<MediaSegments> call(
    PlaybackEngine engine,
    Duration duration, {
    SegmentQuery? query,
  }) async {
    final fromChapters = segmentsFromChapters(
      await engine.chapters(),
      duration,
    ).fittedTo(duration);
    final remote = _remote;
    if (fromChapters.isComplete || remote == null || query == null) {
      return fromChapters;
    }
    try {
      final found = await remote.find(query);
      return fromChapters.orElse(found.fittedTo(duration));
    } on Failure {
      return fromChapters;
    }
  }
}
