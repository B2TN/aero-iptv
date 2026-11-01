@Tags(['libmpv'])
library;

import 'dart:async';
import 'dart:io';

import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/src/media_kit_engine.dart';
import 'package:iptv_player/src/memory_tier.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:test/test.dart';

import '../support/one_connection_panel.dart';
import '../support/test_mkv.dart';

/// media_kit libère mpv cinq secondes après sa fermeture. Le processus doit lui
/// survivre : mpv appellerait sinon un rappel Dart déjà détruit.
const Duration _mpvShutdown = Duration(seconds: 6);

/// Un panneau lent à libérer sa connexion : chaque coupure bloque la vidéo.
const Duration _slowRelease = Duration(seconds: 3);

Future<void> _waitForPlaying(MediaKitEngine engine) => engine.states
    .firstWhere((state) => state.status == PlaybackStatus.playing)
    .timeout(const Duration(seconds: 30));

/// Vrai libmpv et vrai fichier Matroska, dont l'index est en fin de fichier.
void main() {
  final file = buildTestMkv(clusters: 1500);

  setUpAll(
    () => initializePlaybackEngine(libmpv: Platform.environment['LIBMPV_PATH']),
  );

  tearDownAll(() => Future<void>.delayed(_mpvShutdown));

  test('choisir une piste ne bloque pas la vidéo', () async {
    final panel = await OneConnectionPanel.start(
      file,
      releaseDelay: _slowRelease,
    );
    addTearDown(panel.close);
    final engine = MediaKitEngine(tier: MemoryTier.low);
    await (engine.player.platform! as mk.NativePlayer).setProperty(
      'ao',
      'null',
    );

    await engine.open(
      PlaybackRequest(stream: ResolvedStream(url: panel.url), isLive: false),
    );
    await _waitForPlaying(engine);
    await engine.selectSubtitle(null);
    await Future<void>.delayed(const Duration(seconds: 4));
    final connections = panel.ranges.length;
    final position = engine.state.position;

    final blocked = <PlaybackState>[];
    final watcher = engine.states
        .where((state) => state.status == PlaybackStatus.buffering)
        .listen(blocked.add);
    await engine.selectSubtitle(engine.state.subtitleTracks.single);
    await Future<void>.delayed(const Duration(seconds: 5));
    await watcher.cancel();

    expect(panel.ranges, hasLength(connections));
    expect(blocked, isEmpty);
    expect(
      engine.state.position - position,
      greaterThan(const Duration(seconds: 4)),
    );
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('un sous-titre intégré sort ses répliques', () async {
    final panel = await OneConnectionPanel.start(file);
    addTearDown(panel.close);
    final engine = MediaKitEngine(tier: MemoryTier.low);
    await (engine.player.platform! as mk.NativePlayer).setProperty(
      'ao',
      'null',
    );
    final cues = <String>[];
    final watcher = engine.subtitleCues.listen(cues.add);

    await engine.open(
      PlaybackRequest(stream: ResolvedStream(url: panel.url), isLive: false),
    );
    await _waitForPlaying(engine);
    await engine.selectSubtitle(engine.state.subtitleTracks.single);
    await Future<void>.delayed(const Duration(seconds: 7));
    await watcher.cancel();

    expect(cues, contains(startsWith('Line ')));
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 1)));
}
