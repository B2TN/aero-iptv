import 'dart:async';

import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

MediaTrack audio(String id, String? language) =>
    MediaTrack(id: id, kind: MediaTrackKind.audio, language: language);

MediaTrack subtitle(String id, String? language) =>
    MediaTrack(id: id, kind: MediaTrackKind.subtitle, language: language);

const PlaybackItem movie = PlaybackItem(
  sourceId: 1,
  contentKey: 'x:m:1',
  title: 'Inception',
  kind: ContentKind.movie,
  locator: DirectStream('http://s/1.mkv'),
  year: 2010,
);

const PlaybackItem channel = PlaybackItem(
  sourceId: 1,
  contentKey: 'live',
  title: 'TF1',
  kind: ContentKind.live,
  locator: DirectStream('http://s/1.ts'),
);

const PlaybackRequest vodRequest = PlaybackRequest(
  stream: ResolvedStream(url: 'http://s/1.mkv'),
  isLive: false,
);

const PlaybackRequest liveRequest = PlaybackRequest(
  stream: ResolvedStream(url: 'http://s/1.ts'),
  isLive: true,
);

final class FakeEngine implements PlaybackEngine {
  final StreamController<PlaybackState> controller =
      StreamController<PlaybackState>.broadcast();
  final List<PlaybackRequest> opened = [];
  final List<MediaTrack?> selected = [];
  final List<SubtitleFile> loaded = [];
  bool disposed = false;

  @override
  PlaybackState state = const PlaybackState();

  void emit(PlaybackState next) {
    state = next;
    controller.add(next);
  }

  @override
  Stream<PlaybackState> get states => controller.stream;

  @override
  Future<void> open(PlaybackRequest request) async => opened.add(request);

  @override
  Future<void> selectSubtitle(MediaTrack? track) async => selected.add(track);

  @override
  Future<void> loadSubtitle(SubtitleFile file) async => loaded.add(file);

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double percent) async {}

  @override
  Stream<String> get subtitleCues => const Stream.empty();

  @override
  Future<void> selectAudio(MediaTrack track) async {}
}

final class FakeProgress implements WatchProgressRepository {
  final List<WatchProgress> saved = [];
  final List<String> removed = [];

  @override
  Future<void> save(WatchProgress progress) async => saved.add(progress);

  @override
  Future<void> remove(int sourceId, String contentKey) async =>
      removed.add(contentKey);

  @override
  Future<List<WatchProgress>> continueWatching(
    int sourceId, {
    int limit = 20,
  }) async => saved;
}

final class FakeSubtitles implements SubtitleRepository {
  FakeSubtitles({this.result, this.failure});

  final SubtitleFile? result;
  final Failure? failure;
  final List<SubtitleQuery> queries = [];

  @override
  bool get isAvailable => true;

  @override
  Future<void> remember(SubtitleQuery query, SubtitleFile file) async {}

  @override
  Future<SubtitleFile?> find(SubtitleQuery query) async {
    queries.add(query);
    final error = failure;
    if (error != null) throw error;
    return result;
  }
}

void main() {
  group('normalizeLanguageCode', () {
    test('ramène les variantes à un code ISO 639-1', () {
      for (final value in [
        'fr',
        'FR',
        'fre',
        'fra',
        'French',
        'français',
        'fr-FR',
      ]) {
        expect(normalizeLanguageCode(value), 'fr', reason: value);
      }
      expect(normalizeLanguageCode('ger'), 'de');
      expect(normalizeLanguageCode('ara'), 'ar');
    });

    test('rejette une valeur vide ou inconnue', () {
      expect(normalizeLanguageCode(null), isNull);
      expect(normalizeLanguageCode(' '), isNull);
      expect(normalizeLanguageCode('und'), isNull);
    });
  });

  group('ChooseSubtitle', () {
    const choose = ChooseSubtitle();

    test('ne cherche rien si l audio est dans la bonne langue', () {
      final choice = choose(
        audioTracks: [audio('1', 'fre')],
        subtitleTracks: const [],
        preferredLanguage: 'fr',
      );
      expect(choice, isA<SubtitlesNotNeeded>());
    });

    test('utilise la piste sélectionnée, pas la première', () {
      final choice = choose(
        audioTracks: [audio('1', 'fre'), audio('2', 'eng')],
        subtitleTracks: const [],
        selectedAudioId: '2',
        preferredLanguage: 'fr',
      );
      expect(choice, isA<FetchExternalSubtitles>());
    });

    test('préfère une piste intégrée dans la bonne langue', () {
      final choice = choose(
        audioTracks: [audio('1', 'eng')],
        subtitleTracks: [subtitle('3', 'ger'), subtitle('4', 'fra')],
        preferredLanguage: 'fr',
      );
      expect((choice as UseEmbeddedSubtitles).track.id, '4');
    });

    test('cherche à l extérieur si la langue est mauvaise', () {
      final choice = choose(
        audioTracks: [audio('1', 'eng')],
        subtitleTracks: [subtitle('3', 'ger')],
        preferredLanguage: 'fr',
      );
      expect((choice as FetchExternalSubtitles).language, 'fr');
    });

    test('cherche à l extérieur si la langue est inconnue', () {
      final choice = choose(
        audioTracks: [audio('1', null)],
        subtitleTracks: const [],
        preferredLanguage: 'fr',
      );
      expect(choice, isA<FetchExternalSubtitles>());
    });
  });

  group('PlaybackSession', () {
    late FakeEngine engine;
    late FakeProgress progress;

    PlaybackSession session({
      FakeSubtitles? subtitles,
      void Function(Failure)? onFailure,
    }) => PlaybackSession(
      engine: engine,
      progress: progress,
      subtitles: subtitles ?? FakeSubtitles(),
      onSubtitleFailure: onFailure,
      clock: () => DateTime.utc(2026),
    );

    Future<void> flush() => Future<void>.delayed(Duration.zero);

    PlaybackState playing(int seconds, {int duration = 7200}) => PlaybackState(
      status: PlaybackStatus.playing,
      position: Duration(seconds: seconds),
      duration: Duration(seconds: duration),
    );

    setUp(() {
      engine = FakeEngine();
      progress = FakeProgress();
    });

    test('charge des sous-titres externes si nécessaire', () async {
      const file = SubtitleFile(content: 'srt', language: 'fr', title: 'x');
      final subtitles = FakeSubtitles(result: file);
      await session(
        subtitles: subtitles,
      ).play(vodRequest, movie, preferredLanguage: 'fr');

      engine.emit(
        PlaybackState(tracksReady: true, audioTracks: [audio('1', 'eng')]),
      );
      await flush();

      expect(subtitles.queries.single.year, 2010);
      expect(engine.loaded.single, same(file));
    });

    test('active une piste intégrée sans appeler le service', () async {
      final subtitles = FakeSubtitles();
      await session(
        subtitles: subtitles,
      ).play(vodRequest, movie, preferredLanguage: 'fr');

      engine.emit(
        PlaybackState(
          tracksReady: true,
          audioTracks: [audio('1', 'eng')],
          subtitleTracks: [subtitle('2', 'fre')],
        ),
      );
      await flush();

      expect(engine.selected.single!.id, '2');
      expect(subtitles.queries, isEmpty);
    });

    test('ne décide qu une fois par contenu', () async {
      final subtitles = FakeSubtitles();
      await session(
        subtitles: subtitles,
      ).play(vodRequest, movie, preferredLanguage: 'fr');

      final state = PlaybackState(
        tracksReady: true,
        audioTracks: [audio('1', 'eng')],
      );
      engine
        ..emit(state)
        ..emit(state);
      await flush();

      expect(subtitles.queries, hasLength(1));
    });

    test('une erreur de sous-titres n interrompt pas la lecture', () async {
      final failures = <Failure>[];
      await session(
        subtitles: FakeSubtitles(failure: const RateLimitFailure('quota')),
        onFailure: failures.add,
      ).play(vodRequest, movie, preferredLanguage: 'fr');

      engine.emit(
        PlaybackState(tracksReady: true, audioTracks: [audio('1', 'eng')]),
      );
      await flush();

      expect(failures.single, isA<RateLimitFailure>());
      expect(engine.loaded, isEmpty);
    });

    test('ne cherche pas de sous-titres en direct', () async {
      final subtitles = FakeSubtitles();
      await session(
        subtitles: subtitles,
      ).play(liveRequest, channel, preferredLanguage: 'fr');

      engine.emit(
        PlaybackState(tracksReady: true, audioTracks: [audio('1', 'eng')]),
      );
      await flush();

      expect(subtitles.queries, isEmpty);
    });

    test('enregistre la position toutes les 15 secondes', () async {
      await session().play(vodRequest, movie, preferredLanguage: 'fr');

      for (var second = 1; second <= 31; second++) {
        engine.emit(playing(second));
        await flush();
      }

      expect(progress.saved.map((p) => p.position.inSeconds), [15, 30]);
    });

    test('enregistre la position à la fermeture', () async {
      final current = session();
      await current.play(vodRequest, movie, preferredLanguage: 'fr');
      engine.emit(playing(5));
      await current.close();

      expect(progress.saved.single.position.inSeconds, 5);
      expect(engine.disposed, isTrue);
    });

    test('retire un contenu terminé de la reprise', () async {
      final current = session();
      await current.play(vodRequest, movie, preferredLanguage: 'fr');
      engine.emit(playing(7000));
      await current.close();

      expect(progress.saved, isEmpty);
      expect(progress.removed, ['x:m:1']);
    });

    test('n enregistre pas les chaînes en direct', () async {
      final current = session();
      await current.play(liveRequest, channel, preferredLanguage: 'fr');
      engine.emit(playing(600));
      await flush();
      await current.close();

      expect(progress.saved, isEmpty);
    });

    test('reprend sans réenregistrer la position de départ', () async {
      final request = PlaybackRequest(
        stream: const ResolvedStream(url: 'http://s/1.mkv'),
        isLive: false,
        startAt: const Duration(minutes: 30),
      );
      await session().play(request, movie, preferredLanguage: 'fr');
      engine.emit(playing(1802));
      await flush();

      expect(progress.saved, isEmpty);
    });

    test('change de chaîne sans recréer le moteur', () async {
      final current = session();
      await current.play(liveRequest, channel, preferredLanguage: 'fr');
      await current.play(liveRequest, channel, preferredLanguage: 'fr');

      expect(engine.opened, hasLength(2));
      expect(engine.disposed, isFalse);
    });
  });
}
