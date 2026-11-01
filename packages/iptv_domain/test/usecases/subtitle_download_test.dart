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

SubtitleFile _file(String language) =>
    SubtitleFile(content: 'texte', language: language, title: 'Dexter');

final class _Engine implements PlaybackEngine {
  _Engine({this.tracks = const []});

  final List<MediaTrack> tracks;
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();
  final StreamController<String> cues = StreamController<String>.broadcast();
  final List<SubtitleFile> loaded = [];
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
  Future<void> loadSubtitle(SubtitleFile file) async => loaded.add(file);

  @override
  Future<void> dispose() async {
    await _states.close();
    await cues.close();
  }
}

final class _Subtitles implements SubtitleRepository {
  _Subtitles(this.available, {this.isAvailable = true, this.failure});

  final Set<String> available;
  final Failure? failure;
  final List<String> remembered = [];

  @override
  final bool isAvailable;

  @override
  Future<SubtitleFile?> find(SubtitleQuery query) async {
    final error = failure;
    if (error != null) throw error;
    return available.contains(query.language) ? _file(query.language) : null;
  }

  @override
  Future<void> remember(SubtitleQuery query, SubtitleFile file) async =>
      remembered.add(query.language);
}

final class _Translator implements SubtitleTranslator {
  @override
  Future<List<String>> translateTexts(
    List<String> texts, {
    required String language,
  }) async => texts;

  @override
  Future<SubtitleFile> translate(
    SubtitleFile file, {
    required String language,
  }) async => _file(language);
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

  @override
  Future<SubtitleFile> translate(
    SubtitleFile file, {
    required String language,
  }) async => file;
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
  Future<(SubtitleDownload, _Engine, _Subtitles)> download(
    _Subtitles subtitles, {
    SubtitleTranslator? translator,
    String language = 'fr',
  }) async {
    final engine = _Engine();
    final session = PlaybackSession(
      engine: engine,
      progress: _NoProgress(),
      subtitles: subtitles,
      translator: translator,
    );
    await session.play(
      const PlaybackRequest(
        stream: ResolvedStream(url: 'http://s/1.mkv'),
        isLive: false,
      ),
      _item,
      preferredLanguage: language,
    );
    return (await session.downloadSubtitles(), engine, subtitles);
  }

  test('préfère les sous-titres déjà dans la bonne langue', () async {
    final (result, engine, _) = await download(
      _Subtitles({'fr', 'en'}),
      translator: _Translator(),
    );
    expect(result, SubtitleDownload.loaded);
    expect(engine.loaded.single.language, 'fr');
  });

  test('traduit l anglais et conserve le résultat', () async {
    final (result, engine, subtitles) = await download(
      _Subtitles({'en'}),
      translator: _Translator(),
    );
    expect(result, SubtitleDownload.loaded);
    expect(engine.loaded.single.language, 'fr');
    expect(subtitles.remembered, ['fr']);
  });

  test('charge l anglais sans service de traduction', () async {
    final (result, engine, _) = await download(_Subtitles({'en'}));
    expect(result, SubtitleDownload.untranslated);
    expect(engine.loaded.single.language, 'en');
  });

  test('signale qu aucun sous-titre n existe', () async {
    final (result, engine, _) = await download(
      _Subtitles({}),
      translator: _Translator(),
    );
    expect(result, SubtitleDownload.notFound);
    expect(engine.loaded, isEmpty);
  });

  test('sans piste à traduire, une panne en ligne est remontée', () async {
    await expectLater(
      download(
        _Subtitles({}, failure: const NetworkFailure('hors ligne')),
        translator: _Translator(),
      ),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('signale un service non configuré', () async {
    final (result, _, _) = await download(
      _Subtitles({}, isAvailable: false),
      translator: _Translator(),
    );
    expect(result, SubtitleDownload.notConfigured);
  });

  group('piste du flux', () {
    Future<(PlaybackSession, _Engine, List<String>)> start(
      List<MediaTrack> tracks,
      SubtitleTranslator translator, {
      void Function(Failure failure)? onFailure,
      _Subtitles? online,
    }) async {
      final engine = _Engine(tracks: tracks);
      final session = PlaybackSession(
        engine: engine,
        progress: _NoProgress(),
        subtitles: online ?? _Subtitles({}, isAvailable: false),
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

      expect(await session.downloadSubtitles(), SubtitleDownload.loaded);
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

        await session.downloadSubtitles(language: 'de');
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

      await session.downloadSubtitles(language: 'de');
      engine.cues.add('Hello');
      await settle();
      await settle();
      await session.downloadSubtitles(language: 'es');
      await settle();
      await settle();

      expect(shown.last, 'es:Hello');
    });

    test('une traduction peut arriver après le début de la lecture', () async {
      final translator = _CueTranslator();
      final engine = _Engine(tracks: [_track('1', 'eng')]);
      final session = PlaybackSession(
        engine: engine,
        progress: _NoProgress(),
        subtitles: _Subtitles({}, isAvailable: false),
      );
      await session.play(
        const PlaybackRequest(
          stream: ResolvedStream(url: 'http://s/1.mkv'),
          isLive: false,
        ),
        _item,
        preferredLanguage: 'fr',
      );

      session.translator = translator;

      expect(await session.downloadSubtitles(), SubtitleDownload.loaded);
      expect(engine.selected.single?.id, '1');
    });

    test('préfère une piste complète à une piste forcée', () async {
      final (session, engine, _) = await start([
        _track('1', 'eng', title: 'English [Forced]'),
        _track('2', 'eng', title: 'English'),
      ], _CueTranslator());

      await session.downloadSubtitles();

      expect(engine.selected.single?.id, '2');
    });

    test('prend une autre langue en l absence d anglais', () async {
      final (session, engine, _) = await start([
        _track('1', 'ger'),
      ], _CueTranslator());

      await session.downloadSubtitles();

      expect(engine.selected.single?.id, '1');
    });

    test('une piste déjà dans la bonne langue n est pas traduite', () async {
      final translator = _CueTranslator();
      final (session, engine, shown) = await start([
        _track('1', 'eng'),
        _track('2', 'fre'),
      ], translator);

      await session.downloadSubtitles();
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

      expect(await session.downloadSubtitles(), SubtitleDownload.imagesOnly);
      expect(engine.selected, isEmpty);
    });

    test('une panne garde le texte d origine et le signale', () async {
      final failures = <Failure>[];
      final (session, engine, shown) = await start(
        [_track('1', 'eng')],
        _CueTranslator(failure: const NetworkFailure('hors ligne')),
        onFailure: failures.add,
      );

      await session.downloadSubtitles();
      engine.cues.add('Hello');
      await settle();
      await settle();

      expect(shown, ['Hello']);
      expect(failures, hasLength(1));
    });

    test(
      'un fichier complet en ligne passe avant la traduction à la volée',
      () async {
        final translator = _CueTranslator();
        final (session, engine, shown) = await start(
          [_track('1', 'eng')],
          translator,
          online: _Subtitles({'en'}),
        );

        expect(await session.downloadSubtitles(), SubtitleDownload.loaded);
        engine.cues.add('Bonjour');
        await settle();

        expect(engine.loaded, hasLength(1));
        expect(engine.selected, isEmpty);
        expect(shown, ['Bonjour']);
        expect(translator.calls, 0);
      },
    );

    test('un fichier chargé arrête la traduction précédente', () async {
      final translator = _CueTranslator();
      final online = _Subtitles({});
      final (session, engine, shown) = await start(
        [_track('1', 'eng')],
        translator,
        online: online,
      );
      await session.downloadSubtitles();
      online.available.add('fr');

      await session.downloadSubtitles();
      engine.cues.add('Bonjour');
      await settle();

      expect(shown, ['Bonjour']);
      expect(translator.calls, 0);
    });

    test('sans fichier en ligne, traduit la piste du flux', () async {
      final (session, engine, _) = await start(
        [_track('1', 'eng')],
        _CueTranslator(),
        online: _Subtitles({}),
      );

      expect(await session.downloadSubtitles(), SubtitleDownload.loaded);
      expect(engine.selected.single?.id, '1');
    });

    test(
      'une panne du service en ligne se rabat sur la piste du flux',
      () async {
        final (session, engine, _) = await start(
          [_track('1', 'eng')],
          _CueTranslator(),
          online: _Subtitles({}, failure: const NetworkFailure('hors ligne')),
        );

        expect(await session.downloadSubtitles(), SubtitleDownload.loaded);
        expect(engine.selected.single?.id, '1');
      },
    );

    test('une piste dans la bonne langue évite le service en ligne', () async {
      final (session, engine, _) = await start(
        [_track('1', 'fre')],
        _CueTranslator(),
        online: _Subtitles({'fr'}),
      );

      await session.downloadSubtitles();

      expect(engine.selected.single?.id, '1');
      expect(engine.loaded, isEmpty);
    });

    test('choisir une autre piste arrête la traduction', () async {
      final translator = _CueTranslator();
      final (session, engine, shown) = await start([
        _track('1', 'eng'),
      ], translator);

      await session.downloadSubtitles();
      session.stopSubtitleTranslation();
      engine.cues.add('Hello');
      await settle();

      expect(shown, ['Hello']);
      expect(translator.calls, 0);
    });
  });
}
