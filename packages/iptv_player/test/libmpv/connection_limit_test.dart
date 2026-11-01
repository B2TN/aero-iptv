@Tags(['libmpv'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/src/media_kit_engine.dart';
import 'package:iptv_player/src/memory_tier.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:test/test.dart';

import '../support/one_connection_panel.dart';

const int _frameBytes = 960;
const int _frames = 60000;

/// media_kit libère mpv cinq secondes après sa fermeture. Le processus doit lui
/// survivre : mpv appellerait sinon un rappel Dart déjà détruit.
const Duration _mpvShutdown = Duration(seconds: 6);

/// Fichier MP3 silencieux de 57 Mio, plus gros que le tampon du lecteur : la
/// connexion reste donc ouverte. Son démultiplexeur lit la fin du fichier à
/// l'ouverture, comme MKV et MP4 pour leur index : c'est ce qui fait ouvrir une
/// seconde connexion à FFmpeg.
Uint8List _buildFile() {
  final frame = Uint8List(_frameBytes)
    ..setRange(0, 4, const [0xFF, 0xFB, 0xE4, 0x00]);
  final file = BytesBuilder(copy: false);
  for (var i = 0; i < _frames; i++) {
    file.add(frame);
  }
  return file.takeBytes();
}

Future<MediaKitEngine> _silentEngine() async {
  final engine = MediaKitEngine(tier: MemoryTier.low);
  await (engine.player.platform! as mk.NativePlayer).setProperty('ao', 'null');
  return engine;
}

PlaybackRequest _film(OneConnectionPanel panel) =>
    PlaybackRequest(stream: ResolvedStream(url: panel.url), isLive: false);

Future<void> _waitForPlaying(MediaKitEngine engine) =>
    engine.state.status == PlaybackStatus.playing
    ? Future.value()
    : engine.states
          .firstWhere((state) => state.status == PlaybackStatus.playing)
          .timeout(const Duration(seconds: 15));

/// Tests contre un vrai libmpv, sur un panneau limité à une connexion.
void main() {
  final file = _buildFile();

  setUpAll(
    () => initializePlaybackEngine(libmpv: Platform.environment['LIBMPV_PATH']),
  );

  tearDownAll(() => Future<void>.delayed(_mpvShutdown));

  test('un film s ouvre sans deuxième connexion au panneau', () async {
    final panel = await OneConnectionPanel.start(file);
    addTearDown(panel.close);
    final engine = await _silentEngine();

    await engine.open(_film(panel));
    await _waitForPlaying(engine);
    await Future<void>.delayed(const Duration(seconds: 3));

    expect(engine.state.status, PlaybackStatus.playing);
    expect(panel.mostActive, 1);
    expect(panel.ranges.length, greaterThan(1));
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('se déplacer dans un film garde une seule connexion', () async {
    final panel = await OneConnectionPanel.start(file);
    addTearDown(panel.close);
    final engine = await _silentEngine();

    await engine.open(_film(panel));
    await _waitForPlaying(engine);

    await engine.seek(const Duration(minutes: 20));
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(engine.state.position, greaterThan(const Duration(minutes: 19)));
    final before = panel.ranges.length;

    // Revenir au début sort du tampon arrière : il faut rouvrir une connexion.
    await engine.seek(const Duration(minutes: 1));
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(panel.ranges.length, greaterThan(before));
    expect(panel.mostActive, 1);
    expect(engine.state.position, greaterThan(const Duration(seconds: 59)));
    expect(engine.state.position, lessThan(const Duration(minutes: 2)));
    expect(engine.state.status, PlaybackStatus.playing);
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('attend qu un panneau lent libère la connexion coupée', () async {
    final panel = await OneConnectionPanel.start(
      file,
      releaseDelay: const Duration(milliseconds: 1500),
    );
    addTearDown(panel.close);
    final engine = await _silentEngine();

    await engine.open(_film(panel));
    await _waitForPlaying(engine);
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(panel.refused, greaterThan(0));
    expect(engine.state.status, PlaybackStatus.playing);
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('supporte un panneau plus lent que le délai de mpv', () async {
    final panel = await OneConnectionPanel.start(
      file,
      releaseDelay: const Duration(seconds: 7),
    );
    addTearDown(panel.close);
    final engine = await _silentEngine();

    await engine.open(_film(panel));
    await _waitForPlaying(engine);
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(engine.state.status, PlaybackStatus.playing);
    expect(engine.state.position, greaterThan(Duration.zero));
    expect(panel.mostActive, 1);
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('quitter libère la connexion du panneau', () async {
    final panel = await OneConnectionPanel.start(file);
    addTearDown(panel.close);
    final engine = await _silentEngine();

    await engine.open(_film(panel));
    await _waitForPlaying(engine);
    expect(panel.active, 1);

    await engine.dispose();
    await Future<void>.delayed(const Duration(seconds: 2));

    expect(panel.active, 0);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('un compte vraiment occupé échoue aussitôt', () async {
    final panel = await OneConnectionPanel.start(file, refuseAll: true);
    addTearDown(panel.close);
    final engine = await _silentEngine();

    final clock = Stopwatch()..start();
    await engine.open(_film(panel));
    await engine.states
        .firstWhere((state) => state.status == PlaybackStatus.failed)
        .timeout(const Duration(seconds: 15));

    expect(clock.elapsed, lessThan(const Duration(seconds: 3)));
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  group('direct', () {
    PlaybackRequest channel(String url) =>
        PlaybackRequest(stream: ResolvedStream(url: url), isLive: true);

    /// Façade qui renvoie vers le serveur de flux, comme les panneaux Xtream.
    Future<String> behindRedirect(OneConnectionPanel panel) async {
      final front = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => front.close(force: true));
      front.listen((request) {
        unawaited(request.response.redirect(Uri.parse(panel.url)));
      });
      return 'http://127.0.0.1:${front.port}/live/compte/secret/1.ts';
    }

    test('démarre sur un serveur qui refuse les positions', () async {
      final panel = await OneConnectionPanel.start(
        file,
        announcesSize: false,
        refusesRanges: true,
      );
      addTearDown(panel.close);
      final engine = await _silentEngine();

      await engine.open(channel(await behindRedirect(panel)));
      await _waitForPlaying(engine);
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(engine.state.status, PlaybackStatus.playing);
      expect(panel.ranges, everyElement(isNull));
      expect(panel.mostActive, 1);
      await engine.dispose();
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('attend une chaîne que le serveur doit réveiller', () async {
      final panel = await OneConnectionPanel.start(file, announcesSize: false)
        ..answerDelay = const Duration(seconds: 7);
      addTearDown(panel.close);
      final engine = await _silentEngine();

      await engine.open(channel(await behindRedirect(panel)));
      await _waitForPlaying(engine);

      expect(engine.state.status, PlaybackStatus.playing);
      await engine.dispose();
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  test('le lecteur ne voit jamais l adresse du compte', () async {
    final panel = await OneConnectionPanel.start(file);
    addTearDown(panel.close);
    final engine = await _silentEngine();

    await engine.open(_film(panel));
    await _waitForPlaying(engine);

    final opened = engine.player.state.playlist.medias.single.uri;
    expect(opened, isNot(contains('secret')));
    expect(opened, startsWith('http://127.0.0.1'));
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));
}
