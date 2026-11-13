import 'dart:async';

import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

const PlaybackItem _item = PlaybackItem(
  sourceId: 1,
  contentKey: 'x:e:1',
  title: 'Dexter',
  kind: ContentKind.series,
  locator: DirectStream('http://s/1.mkv'),
  season: 1,
  episode: 2,
);

final class _Engine implements PlaybackEngine {
  _Engine({this.tracks = const []});

  final List<MediaTrack> tracks;
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();
  final StreamController<String> cues = StreamController<String>.broadcast();
  final List<MediaTrack?> selected = [];

  @override
  PlaybackState get state => PlaybackState(subtitleTracks: tracks);

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  Future<void> open(PlaybackRequest request) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double percent) async {}

  @override
  Stream<String> get subtitleCues => cues.stream;

  @override
  Future<void> selectAudio(MediaTrack track) async {}

  @override
  Future<void> selectSubtitle(MediaTrack? track) async => selected.add(track);

  @override
  Future<List<MediaChapter>> chapters() async => const [];

  @override
  Future<void> dispose() async {
    await _states.close();
    await cues.close();
  }
}

/// Traduction de réplique, ou panne si [failure] est renseignée.
final class _CueTranslator implements SubtitleTranslator {
  _CueTranslator({this.failure});

  final Failure? failure;
  int calls = 0;

  @override
  Future<List<String>> translateTexts(
    List<String> texts, {
    required String language,
  }) async {
    calls++;
    final error = failure;
    if (error != null) throw error;
    return [for (final text in texts) '$language:$text'];
  }
}

MediaTrack _track(
  String id,
  String language, {
  String codec = 'subrip',
  String? title,
}) => MediaTrack(
  id: id,
  kind: MediaTrackKind.subtitle,
  language: language,
  codec: codec,
  title: title,
);

final class _NoProgress implements WatchProgressRepository {
  @override
  Future<void> save(WatchProgress progress) async {}

  @override
  Future<List<WatchProgress>> continueWatching(
    int sourceId, {
    int limit = 20,
  }) async => const [];

  @override
  Future<void> remove(int sourceId, String contentKey) async {}
}

void main() {
  group('piste du flux', () {
    Future<(PlaybackSession, _Engine, List<String>)> start(
      List<MediaTrack> tracks,
      SubtitleTranslator translator, {
      void Function(Failure failure)? onFailure,
    }) async {
      final engine = _Engine(tracks: tracks);
      final session = PlaybackSession(
        engine: engine,
        progress: _NoProgress(),
        translator: translator,
        onSubtitleFailure: onFailure,
      );
      final shown = <String>[];
      session.subtitleCues.listen(shown.add);
      await session.play(
        const PlaybackRequest(
          stream: ResolvedStream(url: 'http://s/1.mkv'),
          isLive: false,
        ),
        _item,
        preferredLanguage: 'fr',
      );
      return (session, engine, shown);
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('traduit l anglais de préférence, réplique par réplique', () async {
      final translator = _CueTranslator();
      final (session, engine, shown) = await start([
        _track('1', 'ger'),
        _track('2', 'eng'),
      ], translator);

      expect(await session.showSubtitles(), SubtitleOutcome.loaded);
      expect(engine.selected.single?.id, '2');

      engine.cues.add('Hello');
      await settle();
      await settle();
      engine.cues
        ..add('')
        ..add('Hello');
      await settle();
      await settle();

      expect(shown, ['fr:Hello', '', 'fr:Hello']);
      expect(translator.calls, 1);
    });

    test(
      'traduit vers la langue choisie, pas celle de l application',
      () async {
        final translator = _CueTranslator();
        final (session, engine, shown) = await start([
          _track('1', 'eng'),
        ], translator);

        await session.showSubtitles(language: 'de');
        engine.cues.add('Hello');
        await settle();
        await settle();

        expect(shown, ['de:Hello']);
      },
    );

    test('changer de langue ne reprend pas l ancienne traduction', () async {
      final translator = _CueTranslator();
      final (session, engine, shown) = await start([
        _track('1', 'eng'),
      ], translator);

      await session.showSubtitles(language: 'de');
      engine.cues.add('Hello');
      await settle();
      await settle();
      await session.showSubtitles(language: 'es');
      await settle();
      await settle();

      expect(shown.last, 'es:Hello');
    });

    test('une traduction peut arriver après le début de la lecture', () async {
      final translator = _CueTranslator();
      final engine = _Engine(tracks: [_track('1', 'eng')]);
      final session = PlaybackSession(engine: engine, progress: _NoProgress());
      await session.play(
        const PlaybackRequest(
          stream: ResolvedStream(url: 'http://s/1.mkv'),
          isLive: false,
        ),
        _item,
        preferredLanguage: 'fr',
      );

      session.translator = translator;

      expect(await session.showSubtitles(), SubtitleOutcome.loaded);
      expect(engine.selected.single?.id, '1');
    });

    test('préfère une piste complète à une piste forcée', () async {
      final (session, engine, _) = await start([
        _track('1', 'eng', title: 'English [Forced]'),
        _track('2', 'eng', title: 'English'),
      ], _CueTranslator());

      await session.showSubtitles();

      expect(engine.selected.single?.id, '2');
    });

    test('prend une autre langue en l absence d anglais', () async {
      final (session, engine, _) = await start([
        _track('1', 'ger'),
      ], _CueTranslator());

      await session.showSubtitles();

      expect(engine.selected.single?.id, '1');
    });

    test('une piste déjà dans la bonne langue n est pas traduite', () async {
      final translator = _CueTranslator();
      final (session, engine, shown) = await start([
        _track('1', 'eng'),
        _track('2', 'fre'),
      ], translator);

      await session.showSubtitles();
      engine.cues.add('Bonjour');
      await settle();

      expect(engine.selected.single?.id, '2');
      expect(shown, ['Bonjour']);
      expect(translator.calls, 0);
    });

    test('ignore les pistes dessinées en images', () async {
      final (session, engine, _) = await start([
        _track('1', 'eng', codec: 'hdmv_pgs_subtitle'),
      ], _CueTranslator());

      expect(await session.showSubtitles(), SubtitleOutcome.imagesOnly);
      expect(engine.selected, isEmpty);
    });

    test('une panne garde le texte d origine et le signale', () async {
      final failures = <Failure>[];
      final (session, engine, shown) = await start(
        [_track('1', 'eng')],
        _CueTranslator(failure: const NetworkFailure('hors ligne')),
        onFailure: failures.add,
      );

      await session.showSubtitles();
      engine.cues.add('Hello');
      await settle();
      await settle();

      expect(shown, ['Hello']);
      expect(failures, hasLength(1));
    });

    test('sans service de traduction, rien n est traduit', () async {
      final engine = _Engine(tracks: [_track('1', 'eng')]);
      final session = PlaybackSession(engine: engine, progress: _NoProgress());
      await session.play(
        const PlaybackRequest(
          stream: ResolvedStream(url: 'http://s/1.mkv'),
          isLive: false,
        ),
        _item,
        preferredLanguage: 'fr',
      );

      expect(await session.showSubtitles(), SubtitleOutcome.none);
      expect(engine.selected, isEmpty);
    });

    test('choisir une autre piste arrête la traduction', () async {
      final translator = _CueTranslator();
      final (session, engine, shown) = await start([
        _track('1', 'eng'),
      ], translator);

      await session.showSubtitles();
      session.stopSubtitleTranslation();
      engine.cues.add('Hello');
      await settle();

      expect(shown, ['Hello']);
      expect(translator.calls, 0);
    });
  });
}
