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
  Future<List<MediaChapter>> chapters() async => const [];

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
      expect(choice, isA<SubtitlesMissing>());
    });

    test('préfère une piste intégrée dans la bonne langue', () {
      final choice = choose(
        audioTracks: [audio('1', 'eng')],
        subtitleTracks: [subtitle('3', 'ger'), subtitle('4', 'fra')],
        preferredLanguage: 'fr',
      );
      expect((choice as UseEmbeddedSubtitles).track.id, '4');
    });

    test('signale l absence de la langue voulue', () {
      final choice = choose(
        audioTracks: [audio('1', 'eng')],
        subtitleTracks: [subtitle('3', 'ger')],
        preferredLanguage: 'fr',
      );
      expect((choice as SubtitlesMissing).language, 'fr');
    });

    test('une langue d audio inconnue demande des sous-titres', () {
      final choice = choose(
        audioTracks: [audio('1', null)],
        subtitleTracks: const [],
        preferredLanguage: 'fr',
      );
      expect(choice, isA<SubtitlesMissing>());
    });
  });

  group('PlaybackSession', () {
    late FakeEngine engine;
    late FakeProgress progress;

    PlaybackSession session() => PlaybackSession(
      engine: engine,
      progress: progress,
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

    test('active une piste intégrée dans la bonne langue', () async {
      await session().play(vodRequest, movie, preferredLanguage: 'fr');

      engine.emit(
        PlaybackState(
          tracksReady: true,
          audioTracks: [audio('1', 'eng')],
          subtitleTracks: [subtitle('2', 'fre')],
        ),
      );
      await flush();

      expect(engine.selected.single!.id, '2');
    });

    test('sans piste dans la bonne langue, ne choisit rien', () async {
      await session().play(vodRequest, movie, preferredLanguage: 'fr');

      engine.emit(
        PlaybackState(
          tracksReady: true,
          audioTracks: [audio('1', 'eng')],
          subtitleTracks: [subtitle('2', 'ger')],
        ),
      );
      await flush();

      expect(engine.selected, isEmpty);
    });

    test('ne décide qu une fois par contenu', () async {
      await session().play(vodRequest, movie, preferredLanguage: 'fr');

      final state = PlaybackState(
        tracksReady: true,
        audioTracks: [audio('1', 'eng')],
        subtitleTracks: [subtitle('2', 'fre')],
      );
      engine
        ..emit(state)
        ..emit(state);
      await flush();

      expect(engine.selected, hasLength(1));
    });

    test('ne choisit pas de sous-titres en direct', () async {
      await session().play(liveRequest, channel, preferredLanguage: 'fr');

      engine.emit(
        PlaybackState(
          tracksReady: true,
          audioTracks: [audio('1', 'eng')],
          subtitleTracks: [subtitle('2', 'fre')],
        ),
      );
      await flush();

      expect(engine.selected, isEmpty);
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
