import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

const Duration _episode = Duration(minutes: 45);

Duration _min(int minutes, [int seconds = 0]) =>
    Duration(minutes: minutes, seconds: seconds);

MediaChapter _chapter(String title, Duration start) =>
    MediaChapter(title: title, start: start);

/// Moteur dont seuls les chapitres comptent ici.
final class _Engine implements PlaybackEngine {
  _Engine([this.list = const []]);

  final List<MediaChapter> list;

  @override
  Future<List<MediaChapter>> chapters() async => list;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Remote implements SegmentRepository {
  _Remote(this.answer, {this.failure});

  final MediaSegments answer;
  final Failure? failure;
  final List<SegmentQuery> queries = [];

  @override
  Future<MediaSegments> find(SegmentQuery query) async {
    queries.add(query);
    final error = failure;
    if (error != null) throw error;
    return answer;
  }
}

const SegmentQuery _query = SegmentQuery(title: 'Lagon', season: 1, episode: 2);

void main() {
  group('segmentsFromChapters', () {
    test('reconnaît l intro et le générique à leur titre', () {
      final segments = segmentsFromChapters([
        _chapter('Prologue', Duration.zero),
        _chapter('Opening', _min(2)),
        _chapter('Partie A', _min(3, 30)),
        _chapter('End Credits', _min(43)),
      ], _episode);

      expect(segments.intro?.start, _min(2));
      expect(segments.intro?.end, _min(3, 30));
      expect(segments.credits?.start, _min(43));
      expect(segments.credits?.end, isNull);
    });

    test('comprend les titres français, accents compris', () {
      final segments = segmentsFromChapters([
        _chapter('Générique de début', Duration.zero),
        _chapter('Épisode', _min(1, 30)),
        _chapter('GÉNÉRIQUE DE FIN', _min(42)),
      ], _episode);

      expect(segments.intro?.end, _min(1, 30));
      expect(segments.credits?.start, _min(42));
    });

    test('un titre ambigu se range selon sa place dans la vidéo', () {
      final segments = segmentsFromChapters([
        _chapter('Générique', Duration.zero),
        _chapter('Chapitre 2', _min(1)),
        _chapter('Générique', _min(44)),
      ], _episode);

      expect(segments.intro?.start, Duration.zero);
      expect(segments.credits?.start, _min(44));
    });

    test('des chapitres numérotés ne disent rien', () {
      final segments = segmentsFromChapters([
        _chapter('Chapter 1', Duration.zero),
        _chapter('Chapter 2', _min(10)),
      ], _episode);

      expect(segments.isEmpty, isTrue);
    });
  });

  group('fittedTo', () {
    test('écarte ce qui ne tient pas dans ce montage', () {
      const segments = MediaSegments(
        // Au-delà de la moitié, ce n'est pas une intro.
        intro: SegmentSpan(Duration(minutes: 30), Duration(minutes: 31)),
        // Avant la moitié, ce n'est pas un générique de fin.
        credits: SegmentSpan(Duration(minutes: 10)),
      );

      expect(segments.fittedTo(_episode).isEmpty, isTrue);
    });

    test('refuse une intro sans fin ou trop longue', () {
      expect(
        const MediaSegments(
          intro: SegmentSpan(Duration.zero),
        ).fittedTo(_episode).intro,
        isNull,
      );
      expect(
        const MediaSegments(
          intro: SegmentSpan(Duration.zero, Duration(minutes: 8)),
        ).fittedTo(_episode).intro,
        isNull,
      );
    });

    test('un générique qui finit après la vidéo va jusqu à sa fin', () {
      final credits = const MediaSegments(
        credits: SegmentSpan(Duration(minutes: 43), Duration(minutes: 50)),
      ).fittedTo(_episode).credits;

      expect(credits?.start, _min(43));
      expect(credits?.end, isNull);
    });

    test('sans durée connue, rien n est gardé', () {
      const segments = MediaSegments(
        intro: SegmentSpan(Duration.zero, Duration(minutes: 1)),
      );

      expect(segments.fittedTo(Duration.zero).isEmpty, isTrue);
    });
  });

  group('FindMediaSegments', () {
    test('les chapitres priment sur les bases', () async {
      final remote = _Remote(
        const MediaSegments(
          intro: SegmentSpan(Duration(minutes: 1), Duration(minutes: 2)),
          credits: SegmentSpan(Duration(minutes: 40)),
        ),
      );
      final engine = _Engine([
        _chapter('Intro', Duration.zero),
        _chapter('Épisode', _min(1, 10)),
      ]);

      final segments = await FindMediaSegments(remote)(
        engine,
        _episode,
        query: _query,
      );

      // L'intro vient du fichier, le générique de la base.
      expect(segments.intro?.end, _min(1, 10));
      expect(segments.credits?.start, _min(40));
    });

    test('des chapitres complets évitent les bases', () async {
      final remote = _Remote(MediaSegments.none);
      final engine = _Engine([
        _chapter('Intro', Duration.zero),
        _chapter('Épisode', _min(1)),
        _chapter('Credits', _min(44)),
      ]);

      await FindMediaSegments(remote)(engine, _episode, query: _query);

      expect(remote.queries, isEmpty);
    });

    test('une base injoignable laisse les chapitres', () async {
      final remote = _Remote(
        MediaSegments.none,
        failure: const NetworkFailure('hors ligne'),
      );
      final engine = _Engine([_chapter('Credits', _min(44))]);

      final segments = await FindMediaSegments(remote)(
        engine,
        _episode,
        query: _query,
      );

      expect(segments.credits?.start, _min(44));
      expect(segments.intro, isNull);
    });

    test('sans identité, seuls les chapitres comptent', () async {
      final remote = _Remote(
        const MediaSegments(
          intro: SegmentSpan(Duration.zero, Duration(minutes: 1)),
        ),
      );

      final segments = await FindMediaSegments(remote)(_Engine(), _episode);

      expect(segments.isEmpty, isTrue);
      expect(remote.queries, isEmpty);
    });

    test('une base qui décrit un autre montage est écartée', () async {
      final remote = _Remote(
        const MediaSegments(credits: SegmentSpan(Duration(minutes: 50))),
      );

      final segments = await FindMediaSegments(remote)(
        _Engine(),
        _episode,
        query: _query,
      );

      expect(segments.isEmpty, isTrue);
    });
  });
}
