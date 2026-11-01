@Tags(['libmpv'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/src/media_kit_engine.dart';
import 'package:iptv_player/src/memory_tier.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:test/test.dart';

/// Vérifie que le lecteur produit un vrai son à partir de flux Dolby.
///
/// Les échantillons de la suite de tests de FFmpeg ne sont pas versionnés :
/// `DOLBY_SAMPLES` désigne le dossier qui les contient. La sortie `pcm` de mpv
/// écrit le son décodé dans un fichier, ce qui permet de mesurer le signal au
/// lieu de supposer qu'une lecture sans erreur est audible.

/// Niveau minimal d'un signal audible (-60 dBFS).
const double _audibleRms = 0.001;

/// Niveau minimal d'un signal réel mais très faible (-120 dBFS). L'extrait AC-3
/// provient du tout début d'un film : il reste presque silencieux, et ce test ne
/// peut donc pas prouver qu'il est audible, seulement qu'il est décodé.
const double _quietExcerptRms = 0.000001;

const int _pcmFormat = 1;
const int _floatFormat = 3;
const int _extensibleFormat = 0xFFFE;

/// Mesure d'un fichier WAV.
final class WavMeasure {
  const WavMeasure({
    required this.channels,
    required this.sampleRate,
    required this.bits,
    required this.frames,
    required this.rms,
    required this.peak,
  });

  final int channels;
  final int sampleRate;
  final int bits;
  final int frames;
  final double rms;
  final double peak;

  Duration get duration =>
      Duration(microseconds: frames * 1000000 ~/ sampleRate);
}

WavMeasure measureWav(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var format = 0;
  var channels = 0;
  var sampleRate = 0;
  var bits = 0;
  var offset = 12;

  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, offset, offset + 4);
    final declared = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
      if (format == _extensibleFormat) {
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      // mpv ne réécrit pas toujours la taille à la fermeture du fichier.
      final available = bytes.length - body;
      final size = declared == 0 || declared > available ? available : declared;
      return _measureSamples(
        data,
        body,
        size,
        format: format,
        channels: channels,
        sampleRate: sampleRate,
        bits: bits,
      );
    }
    offset = body + declared + declared.remainder(2);
  }
  throw const FormatException('Bloc data absent du WAV.');
}

WavMeasure _measureSamples(
  ByteData data,
  int start,
  int size, {
  required int format,
  required int channels,
  required int sampleRate,
  required int bits,
}) {
  final bytesPerSample = bits ~/ 8;
  final samples = size ~/ bytesPerSample;
  var energy = 0.0;
  var peak = 0.0;
  for (var i = 0; i < samples; i++) {
    final position = start + i * bytesPerSample;
    final double value = switch ((format, bits)) {
      (_floatFormat, 32) => data.getFloat32(position, Endian.little),
      (_pcmFormat, 16) => data.getInt16(position, Endian.little) / 32768,
      (_pcmFormat, 32) => data.getInt32(position, Endian.little) / 2147483648,
      _ => throw FormatException('Format WAV non géré : $format/$bits.'),
    };
    energy += value * value;
    peak = max(peak, value.abs());
  }
  return WavMeasure(
    channels: channels,
    sampleRate: sampleRate,
    bits: bits,
    frames: samples ~/ channels,
    rms: sqrt(energy / samples),
    peak: peak,
  );
}

mk.NativePlayer nativeOf(MediaKitEngine engine) =>
    engine.player.platform! as mk.NativePlayer;

/// Décode [sample] jusqu'à la fin et mesure le son produit.
Future<Map<String, Object>> decode(
  File sample, {
  required File output,
  required String audioChannels,
}) async {
  final engine = MediaKitEngine(tier: MemoryTier.low);
  final native = nativeOf(engine);
  await native.setProperty('ao', 'pcm');
  await native.setProperty('ao-pcm-file', output.path);
  await native.setProperty('ao-pcm-waveheader', 'yes');
  await native.setProperty('audio-channels', audioChannels);

  final ended = engine.states
      .firstWhere((state) => state.status == PlaybackStatus.ended)
      .timeout(const Duration(seconds: 30));
  await engine.open(
    PlaybackRequest(stream: ResolvedStream(url: sample.path), isLive: false),
  );
  await ended;

  final result = <String, Object>{
    'codec': await native.getProperty('audio-codec-name'),
    'decoded': await native.getProperty('audio-params/format'),
    'sourceChannels': await native.getProperty('audio-params/channel-count'),
    'spdif': await native.getProperty('audio-spdif'),
  };
  await engine.dispose();
  result['wav'] = measureWav(output);
  return result;
}

void main() {
  final directory = Platform.environment['DOLBY_SAMPLES'];
  final libmpv = Platform.environment['LIBMPV_PATH'];

  // Un `skip` serait annulé par `--run-skipped`, utilisé pour ces tests réels.
  if (directory == null) return;

  group('flux Dolby', () {
    late Directory temporary;

    setUpAll(() => initializePlaybackEngine(libmpv: libmpv));

    setUp(() async {
      temporary = await Directory.systemTemp.createTemp('iptv_dolby');
    });

    tearDown(() => temporary.delete(recursive: true));

    void describeSample(
      String name,
      String fileName,
      String codec, {
      required double minimumRms,
    }) {
      File sample() => File('$directory/$fileName');

      Future<WavMeasure> check(String channels, int expected) async {
        final result = await decode(
          sample(),
          output: File('${temporary.path}/out.wav'),
          audioChannels: channels,
        );
        final wav = result['wav']! as WavMeasure;
        // ignore: avoid_print
        print(
          '$name [$channels] : codec=${result['codec']}, '
          'décodé=${result['decoded']}, '
          'canaux source=${result['sourceChannels']}, '
          'sortie=${wav.channels} canaux ${wav.sampleRate} Hz, '
          '${wav.duration.inMilliseconds} ms, '
          'RMS=${wav.rms.toStringAsFixed(4)}, '
          'crête=${wav.peak.toStringAsFixed(4)}',
        );

        expect(result['codec'], codec);
        expect(result['spdif'], isEmpty);
        expect('${result['decoded']}', isNot(startsWith('spdif')));
        expect(wav.channels, expected);
        expect(wav.frames, greaterThan(0));
        expect(wav.rms, greaterThan(minimumRms));
        return wav;
      }

      test('$name : décodé en stéréo, comme sur Android', () async {
        await check('stereo', 2);
      }, timeout: const Timeout(Duration(minutes: 1)));

      test('$name : 5.1 conservé sur PC', () async {
        await check('5.1', 6);
      }, timeout: const Timeout(Duration(minutes: 1)));
    }

    describeSample(
      'E-AC-3',
      'csi_miami_5.1_256_spx_small.eac3',
      'eac3',
      minimumRms: _audibleRms,
    );
    describeSample(
      'AC-3',
      'monsters_inc_5.1_448_small.ac3',
      'ac3',
      minimumRms: _quietExcerptRms,
    );
  });
}
