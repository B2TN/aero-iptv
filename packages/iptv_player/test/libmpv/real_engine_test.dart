@Tags(['libmpv'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/src/media_kit_engine.dart';
import 'package:iptv_player/src/memory_tier.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:test/test.dart';

/// Tests contre un vrai libmpv : `setProperty` ignorant les erreurs de mpv, une
/// option mal nommée ne se détecterait pas autrement.
///
/// Après `flutter build windows`, depuis `packages/iptv_player` :
///
/// ```powershell
/// $env:LIBMPV_PATH = (Resolve-Path ..\..\app\build\windows\x64\runner\Release\libmpv-2.dll)
/// dart test -j 1 --run-skipped -t libmpv
/// ```

/// Trame MP3 silencieuse à 320 kbit/s et 48 kHz : un en-tête valide suivi de
/// zéros, que le décodeur interprète comme du silence.
const int _frameBytes = 960;
const Duration _frameDuration = Duration(milliseconds: 24);

/// Image PNG d'un pixel : la plus petite piste vidéo que mpv sache ouvrir.
const String _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR'
    '9awAAAABJRU5ErkJggg==';

Uint8List silentFrame() =>
    Uint8List(_frameBytes)..setRange(0, 4, const [0xFF, 0xFB, 0xE4, 0x00]);

/// Sert un flux MP3 au rythme réel, sans jamais se terminer.
Future<HttpServer> startLiveServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final frame = silentFrame();
  server.listen((request) async {
    if (request.uri.path != '/live') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    // Le flux ne se termine jamais : c'est le lecteur qui coupe la connexion.
    // ignore: close_sinks
    final response = request.response
      ..headers.contentType = ContentType('audio', 'mpeg')
      ..bufferOutput = false;
    final clock = Stopwatch()..start();
    var sent = 0;
    try {
      while (true) {
        // Cadencé sur l'horloge : les minuteries Windows manquent de précision.
        final due = clock.elapsedMicroseconds ~/ _frameDuration.inMicroseconds;
        for (; sent <= due; sent++) {
          response.add(frame);
        }
        await response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    } on Object {
      // Le lecteur a fermé la connexion.
    }
  });
  return server;
}

final class _PrefixTranslator implements SubtitleTranslator {
  @override
  Future<List<String>> translateTexts(
    List<String> texts, {
    required String language,
  }) async => [for (final text in texts) '$language:$text'];
}

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

mk.NativePlayer nativeOf(MediaKitEngine engine) =>
    engine.player.platform! as mk.NativePlayer;

/// Ajoute une piste de sous-titres au flux en cours, comme un fichier externe.
Future<void> addSubtitleTrack(
  MediaKitEngine engine,
  String content, {
  required String language,
}) => engine.player.setSubtitleTrack(
  mk.SubtitleTrack.data(content, title: 'Essai', language: language),
);

/// Crée un moteur muet : ce test ne doit rien jouer sur les haut-parleurs.
Future<MediaKitEngine> silentEngine() async {
  final engine = MediaKitEngine(tier: MemoryTier.low);
  await nativeOf(engine).setProperty('ao', 'null');
  return engine;
}

Future<PlaybackState> waitForStatus(
  MediaKitEngine engine,
  PlaybackStatus status, {
  Duration timeout = const Duration(seconds: 15),
}) {
  if (engine.state.status == status) return Future.value(engine.state);
  return engine.states
      .firstWhere((state) => state.status == status)
      .timeout(timeout);
}

void main() {
  final libmpv = Platform.environment['LIBMPV_PATH'];
  late HttpServer server;

  PlaybackRequest liveRequest({int delay = 0}) => PlaybackRequest(
    stream: ResolvedStream(url: 'http://127.0.0.1:${server.port}/live'),
    isLive: true,
    liveDelaySeconds: delay,
  );

  setUpAll(() async {
    initializePlaybackEngine(libmpv: libmpv);
    server = await startLiveServer();
  });

  tearDownAll(() async {
    await server.close(force: true);
    // media_kit libère mpv cinq secondes après sa fermeture. Le processus doit
    // lui survivre : mpv appellerait sinon un rappel Dart déjà détruit.
    await Future<void>.delayed(const Duration(seconds: 6));
  });

  test('mpv accepte chaque option du profil', () async {
    final engine = await silentEngine();
    await engine.open(liveRequest(delay: 4));
    final native = nativeOf(engine);

    expect(await native.getProperty('cache'), 'yes');
    expect(await native.getProperty('cache-on-disk'), 'no');
    expect(await native.getProperty('demuxer-max-bytes'), '33554432');
    expect(await native.getProperty('demuxer-max-back-bytes'), '0');
    expect(await native.getProperty('demuxer-donate-buffer'), 'no');
    expect(await native.getProperty('audio-spdif'), '');
    expect(await native.getProperty('cache-pause-initial'), 'yes');
    expect(double.parse(await native.getProperty('cache-pause-wait')), 4);
    expect(double.parse(await native.getProperty('cache-secs')), 6);

    await engine.dispose();
  });

  test('le retard diffère le démarrage et se maintient', () async {
    Future<Duration> startupOf(int delay) async {
      final engine = await silentEngine();
      final watch = Stopwatch()..start();
      await engine.open(liveRequest(delay: delay));
      await waitForStatus(engine, PlaybackStatus.playing);
      watch.stop();
      await engine.dispose();
      return watch.elapsed;
    }

    final immediate = await startupOf(0);
    final delayed = await startupOf(4);

    final engine = await silentEngine();
    await engine.open(liveRequest(delay: 4));
    await waitForStatus(engine, PlaybackStatus.playing);
    await Future<void>.delayed(const Duration(seconds: 3));
    final reserve = double.parse(
      await nativeOf(engine).getProperty('demuxer-cache-duration'),
    );
    await engine.dispose();

    // ignore: avoid_print
    print(
      'Démarrage sans retard : ${immediate.inMilliseconds} ms, '
      'avec 4 s de retard : ${delayed.inMilliseconds} ms, '
      'réserve en lecture : ${reserve.toStringAsFixed(1)} s',
    );

    expect(immediate, lessThan(const Duration(seconds: 3)));
    expect(delayed, greaterThan(const Duration(seconds: 3)));
    expect(delayed, lessThan(const Duration(seconds: 8)));
    expect(reserve, greaterThan(3));
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('affiche une piste de sous-titres ajoutée', () async {
    final engine = await silentEngine();
    await engine.open(liveRequest());
    await waitForStatus(engine, PlaybackStatus.playing);

    final shown = engine.player.stream.subtitle
        .firstWhere((lines) => lines.any((line) => line.contains('Bonjour')))
        .timeout(const Duration(seconds: 15));
    await addSubtitleTrack(
      engine,
      '1\n00:00:00,000 --> 01:00:00,000\nBonjour\n',
      language: 'fr',
    );

    expect((await shown).join(), contains('Bonjour'));
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test(
    'traduit vers la langue choisie les répliques d une vraie piste',
    () async {
      final engine = await silentEngine();
      final session = PlaybackSession(
        engine: engine,
        progress: _NoProgress(),
        translator: _PrefixTranslator(),
      );
      await session.play(
        liveRequest(),
        const PlaybackItem(
          sourceId: 1,
          contentKey: 'essai',
          title: 'Essai',
          kind: ContentKind.movie,
          locator: DirectStream('http://s/1.ts'),
        ),
        preferredLanguage: 'fr',
      );
      await waitForStatus(engine, PlaybackStatus.playing);

      final tracks = engine.states
          .firstWhere((state) => state.subtitleTracks.isNotEmpty)
          .timeout(const Duration(seconds: 15));
      await addSubtitleTrack(
        engine,
        '1\n00:00:00,000 --> 01:00:00,000\nHello\n',
        language: 'en',
      );
      await tracks;

      final shown = session.subtitleCues
          .firstWhere((text) => text.contains('Hello'))
          .timeout(const Duration(seconds: 15));
      expect(
        await session.showSubtitles(language: 'de'),
        SubtitleOutcome.loaded,
      );
      expect(await shown, 'de:Hello');
      await session.close();
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test('signale un flux introuvable sans exposer son URL', () async {
    final engine = await silentEngine();
    await engine.open(
      PlaybackRequest(
        stream: ResolvedStream(
          url: 'http://127.0.0.1:${server.port}/live/compte/secret/1.ts',
        ),
        isLive: true,
      ),
    );
    final state = await waitForStatus(engine, PlaybackStatus.failed);

    expect(state.status, PlaybackStatus.failed);
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('signale une sortie vidéo impossible à ouvrir', () async {
    final engine = await silentEngine();
    final directory = await Directory.systemTemp.createTemp('iptv_vo');
    final image = await File(
      '${directory.path}/image.png',
    ).writeAsBytes(base64Decode(_onePixelPng));
    final native = nativeOf(engine);
    // Le contexte Windows ne sait pas créer d'OpenGL ES : mpv perd sa sortie,
    // comme sur un appareil dont le pilote refuserait le contexte.
    await native.setProperty('gpu-api', 'opengl');
    await native.setProperty('gpu-context', 'win');
    await native.setProperty('opengl-es', 'yes');
    await native.setProperty('vo', 'gpu');
    await engine.open(
      PlaybackRequest(stream: ResolvedStream(url: image.path), isLive: false),
    );
    final state = await waitForStatus(engine, PlaybackStatus.failed);

    expect(state.status, PlaybackStatus.failed);
    await engine.dispose();
    await directory.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('enchaîne les chaînes sur le même moteur', () async {
    final engine = await silentEngine();
    for (var i = 0; i < 3; i++) {
      await engine.open(liveRequest());
      await waitForStatus(engine, PlaybackStatus.playing);
    }
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('la mémoire reste stable sur des ouvertures répétées', () async {
    Future<void> cycle() async {
      final engine = await silentEngine();
      await engine.open(liveRequest());
      await waitForStatus(engine, PlaybackStatus.playing);
      await engine.dispose();
    }

    for (var i = 0; i < 5; i++) {
      await cycle();
    }
    final before = ProcessInfo.currentRss;
    for (var i = 0; i < 20; i++) {
      await cycle();
    }
    final growth = ProcessInfo.currentRss - before;
    // ignore: avoid_print
    print('Mémoire après 20 ouvertures : ${growth ~/ (1024 * 1024)} Mio');

    expect(growth, lessThan(40 * 1024 * 1024));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
