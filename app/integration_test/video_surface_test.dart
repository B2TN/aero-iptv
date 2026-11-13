import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/iptv_player.dart';
import 'package:media_kit/media_kit.dart' show NativePlayer, SubtitleTrack;

const int _width = 320;
const int _height = 180;
const int _frames = 150;
const int _framesPerSecond = 25;

List<int> _littleEndian(List<int> values, {int bytes = 4}) {
  final data = ByteData(values.length * bytes);
  for (var i = 0; i < values.length; i++) {
    if (bytes == 4) {
      data.setUint32(i * 4, values[i], Endian.little);
    } else {
      data.setUint16(i * 2, values[i], Endian.little);
    }
  }
  return data.buffer.asUint8List();
}

List<int> _chunk(String id, List<int> data) => [
  ...ascii.encode(id),
  ..._littleEndian([data.length]),
  ...data,
  if (data.length.isOdd) 0,
];

List<int> _list(String type, List<int> data) =>
    _chunk('LIST', [...ascii.encode(type), ...data]);

/// Encapsule des images JPEG dans un AVI minimal, sans aucun outil externe : le
/// libmpv de Windows n'a ni encodeur ni mire, et refuse le MJPEG brut.
List<int> _buildAvi(List<List<int>> jpegs) {
  final mainHeader = _chunk(
    'avih',
    _littleEndian([
      1000000 ~/ _framesPerSecond, // Microsecondes par image.
      0, 0, 0,
      jpegs.length,
      0, 1, 0,
      _width,
      _height,
      0, 0, 0, 0,
    ]),
  );
  final streamHeader = _chunk('strh', [
    ...ascii.encode('vidsMJPG'),
    ..._littleEndian([0, 0, 0, 1, _framesPerSecond, 0, jpegs.length, 0]),
    ..._littleEndian([0xFFFFFFFF, 0]),
    ..._littleEndian([0, 0, _width, _height], bytes: 2),
  ]);
  final streamFormat = _chunk('strf', [
    ..._littleEndian([40, _width, _height]),
    ..._littleEndian([1, 24], bytes: 2),
    ...ascii.encode('MJPG'),
    ..._littleEndian([_width * _height * 3, 0, 0, 0, 0]),
  ]);
  final content = [
    ..._list('hdrl', [
      ...mainHeader,
      ..._list('strl', [...streamHeader, ...streamFormat]),
    ]),
    ..._list('movi', [for (final jpeg in jpegs) ..._chunk('00dc', jpeg)]),
  ];
  return _chunk('RIFF', [...ascii.encode('AVI '), ...content]);
}

/// Écrit six secondes de vidéo compressée.
Future<File> writeTestVideo(Directory directory) async {
  final jpegs = [
    for (var frame = 0; frame < _frames; frame++)
      img.encodeJpg(
        img.fill(
          img.Image(width: _width, height: _height),
          color: img.ColorRgb8(frame % 256, 80, 160),
        ),
      ),
  ];
  return File('${directory.path}/mire.avi').writeAsBytes(_buildAvi(jpegs));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VideoSurface reçoit de vraies images', (tester) async {
    initializePlaybackEngine();
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('iptv_video'),
    ))!;
    final video = (await tester.runAsync(() => writeTestVideo(directory)))!;
    final engine = MediaKitEngine(tier: MemoryTier.desktop);
    if (Platform.isAndroid) {
      // L'EGL de l'émulateur refuse le contexte de mpv sans ce drapeau de
      // débogage, qui ne change rien au test sur un appareil réel.
      await tester.runAsync(
        () => (engine.player.platform! as NativePlayer).setProperty(
          'gpu-debug',
          'yes',
        ),
      );
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: VideoSurface(engine: engine),
      ),
    );
    await tester.runAsync(() async {
      // L'abonnement précède l'ouverture : un fichier local démarre très vite.
      final playing = engine.states
          .firstWhere((state) => state.status == PlaybackStatus.playing)
          .timeout(const Duration(seconds: 20));
      await engine.open(
        PlaybackRequest(stream: ResolvedStream(url: video.path), isLive: false),
      );
      await playing;
      // La traduction lit ce flux : mpv doit fournir le texte, hors de l'image.
      final cue = engine.subtitleCues
          .firstWhere((text) => text.isNotEmpty)
          .timeout(const Duration(seconds: 5));
      await engine.player.setSubtitleTrack(
        SubtitleTrack.data(
          '1\n00:00:00,000 --> 00:10:00,000\nBonjour le lagon\n',
          title: 'Essai',
          language: 'fr',
        ),
      );
      expect(await cue, 'Bonjour le lagon');
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();

    expect(engine.player.state.width, _width);
    expect(engine.player.state.height, _height);
    expect(engine.state.position, greaterThan(Duration.zero));
    expect(engine.state.status, PlaybackStatus.playing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await engine.dispose();
      await directory.delete(recursive: true);
    });
  });
}
