import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const int _videoWidth = 320;
const int _videoHeight = 180;
const int _videoFrames = 250;

/// Fournisseur IPTV factice : playlist, guide, images et vidéo.
///
/// Tout est produit ici, sans réseau ni fichier extérieur.
final class DemoServer {
  DemoServer._(this._server, this._video);

  final HttpServer _server;
  final List<int> _video;

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  static Future<DemoServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final demo = DemoServer._(server, _buildVideo());
    server.listen(demo._handle);
    return demo;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    final response = request.response;
    if (path == '/playlist.m3u') {
      response.write(_playlist());
    } else if (path == '/guide.xml') {
      response.write(_guide());
    } else if (path.startsWith('/poster/')) {
      response.add(_poster(path.split('/').last));
    } else if (path.startsWith('/backdrop/')) {
      response.add(_backdrop(path.split('/').last));
    } else if (path.endsWith('.avi')) {
      response.add(_video);
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }

  String _channel(String id, String name, String group, int stream) =>
      '#EXTINF:-1 tvg-id="$id" tvg-logo="$baseUrl/poster/$id.png" '
      'group-title="$group",$name\n'
      '$baseUrl/live/demo/demo/$stream.avi\n';

  String _vod(String title, String group, String path, int id) =>
      '#EXTINF:-1 tvg-logo="$baseUrl/poster/${title.hashCode.abs()}.png" '
      'group-title="$group",$title\n'
      '$baseUrl/$path/demo/demo/$id.avi\n';

  String _playlist() {
    final buffer = StringBuffer('#EXTM3U url-tvg="$baseUrl/guide.xml"\n');
    const french = ['Lagon 1', 'Lagon 2', 'Horizon', 'Cap Sud', 'Azur Info'];
    var id = 1;
    for (final name in french) {
      final key = name.toLowerCase().replaceAll(' ', '');
      buffer
        ..write(_channel('$key.fr', 'FR: $name FHD', 'FRANCE FHD', id++))
        ..write(_channel('$key.fr', 'FR: $name HD', 'FRANCE HD', id++))
        ..write(_channel('$key.fr', 'FR: $name SD', 'FRANCE SD', id++));
    }
    buffer
      ..write(_channel('sport1.fr', 'FR: Sport Un FHD', 'FR | SPORTS', id++))
      ..write(_channel('sport2.fr', 'FR: Sport Deux HD', 'FR | SPORTS', id++))
      ..write(_channel('news.uk', 'UK: Harbour News HD', 'UK | NEWS', id++))
      ..write(_channel('film.de', 'DE: Kino Eins HD', 'GERMANY FILM', id++))
      ..write(_channel('deportes.es', 'ES: Deportes HD', 'ESPAÑA', id++))
      ..write(_channel('cine.it', 'IT: Cinema Uno', 'ITALIA', id++))
      ..write(_channel('aljazira.ar', 'AR: Qanat Wahid', 'ARABIC', id++));

    const movies = [
      'Le Dernier Récif',
      'Marée Haute',
      'Les Voiles du Nord',
      'Sous la Surface',
      'Archipel',
      'Le Phare',
      'Courants',
      'Nuit Bleue',
    ];
    for (final (index, title) in movies.indexed) {
      buffer.write(_vod('FR - $title (2024)', 'VOD FR', 'movie', 100 + index));
    }

    const series = ['Abysses', 'Port Royal', 'Equinoxe', 'Les Gardiens'];
    for (final (index, title) in series.indexed) {
      for (var episode = 1; episode <= 4; episode++) {
        final number = episode.toString().padLeft(2, '0');
        buffer.write(
          _vod(
            'FR - $title S01 E$number',
            'SERIES FR',
            'series',
            200 + index * 10 + episode,
          ),
        );
        if (index == 0) {
          buffer.write(
            _vod(
              'EN - $title S01 E$number',
              'SERIES EN',
              'series',
              300 + episode,
            ),
          );
        }
      }
    }
    return buffer.toString();
  }

  String _guide() {
    final now = DateTime.now().toUtc();
    String stamp(DateTime time) {
      String two(int value) => value.toString().padLeft(2, '0');
      return '${time.year}${two(time.month)}${two(time.day)}'
          '${two(time.hour)}${two(time.minute)}00 +0000';
    }

    final start = stamp(now.subtract(const Duration(minutes: 20)));
    final stop = stamp(now.add(const Duration(minutes: 40)));
    const shows = {
      'lagon1.fr': 'Journal du soir',
      'lagon2.fr': 'Documentaire : la vie des récifs',
      'horizon.fr': 'Magazine de la mer',
      'capsud.fr': 'Série : Port Royal',
      'azurinfo.fr': 'Édition spéciale',
    };
    final buffer = StringBuffer('<?xml version="1.0" encoding="UTF-8"?><tv>');
    shows.forEach((id, title) {
      buffer.write(
        '<channel id="$id"><display-name>$id</display-name></channel>'
        '<programme start="$start" stop="$stop" channel="$id">'
        '<title lang="fr">$title</title></programme>',
      );
    });
    buffer.write('</tv>');
    return buffer.toString();
  }

  List<int> _poster(String name) {
    final seed = name.hashCode.abs();
    final random = Random(seed);
    final image = img.Image(width: 266, height: 400);
    final hue = random.nextDouble();
    final top = _hsv(hue, 0.65, 0.85);
    final bottom = _hsv((hue + 0.12) % 1, 0.85, 0.3);
    for (var y = 0; y < image.height; y++) {
      final t = y / image.height;
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(
          x,
          y,
          (top[0] + (bottom[0] - top[0]) * t).round(),
          (top[1] + (bottom[1] - top[1]) * t).round(),
          (top[2] + (bottom[2] - top[2]) * t).round(),
        );
      }
    }
    img.fillCircle(
      image,
      x: 60 + random.nextInt(140),
      y: 90 + random.nextInt(150),
      radius: 40 + random.nextInt(50),
      color: img.ColorRgba8(255, 255, 255, 70),
    );
    return img.encodeJpg(image, quality: 80);
  }

  List<int> _backdrop(String name) {
    final random = Random(name.hashCode.abs());
    final image = img.Image(width: 780, height: 320);
    final hue = random.nextDouble();
    final horizon = 200 + random.nextInt(50);
    for (var y = 0; y < image.height; y++) {
      final t = y / image.height;
      for (var x = 0; x < image.width; x++) {
        final color = _hsv(
          (hue + t * 0.14) % 1,
          0.55 + t * 0.3,
          0.98 - t * 0.5,
        );
        image.setPixelRgb(x, y, color[0], color[1], color[2]);
      }
    }
    final sunX = 200 + random.nextInt(380);
    img.fillCircle(
      image,
      x: sunX,
      y: horizon - 70,
      radius: 52,
      color: img.ColorRgba8(255, 240, 200, 230),
    );
    img.fillRect(
      image,
      x1: 0,
      y1: horizon,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(30, 40, 70, 200),
    );
    return img.encodeJpg(image, quality: 82);
  }

  List<int> _hsv(double h, double s, double v) {
    final i = (h * 6).floor();
    final f = h * 6 - i;
    final p = v * (1 - s);
    final q = v * (1 - f * s);
    final t = v * (1 - (1 - f) * s);
    final rgb = switch (i % 6) {
      0 => [v, t, p],
      1 => [q, v, p],
      2 => [p, v, t],
      3 => [p, q, v],
      4 => [t, p, v],
      _ => [v, p, q],
    };
    return [for (final channel in rgb) (channel * 255).round()];
  }
}

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

/// Vidéo AVI de dix secondes, en images JPEG.
List<int> _buildVideo() {
  final frames = [
    for (var frame = 0; frame < _videoFrames; frame++)
      img.encodeJpg(
        img.fill(
          img.Image(width: _videoWidth, height: _videoHeight),
          color: img.ColorRgb8(frame % 256, 90, 170),
        ),
      ),
  ];
  final mainHeader = _chunk(
    'avih',
    _littleEndian([
      40000,
      0,
      0,
      0,
      frames.length,
      0,
      1,
      0,
      _videoWidth,
      _videoHeight,
      0,
      0,
      0,
      0,
    ]),
  );
  final streamHeader = _chunk('strh', [
    ...ascii.encode('vidsMJPG'),
    ..._littleEndian([0, 0, 0, 1, 25, 0, frames.length, 0]),
    ..._littleEndian([0xFFFFFFFF, 0]),
    ..._littleEndian([0, 0, _videoWidth, _videoHeight], bytes: 2),
  ]);
  final streamFormat = _chunk('strf', [
    ..._littleEndian([40, _videoWidth, _videoHeight]),
    ..._littleEndian([1, 24], bytes: 2),
    ...ascii.encode('MJPG'),
    ..._littleEndian([_videoWidth * _videoHeight * 3, 0, 0, 0, 0]),
  ]);
  return _chunk('RIFF', [
    ...ascii.encode('AVI '),
    ..._list('hdrl', [
      ...mainHeader,
      ..._list('strl', [...streamHeader, ...streamFormat]),
    ]),
    ..._list('movi', [for (final frame in frames) ..._chunk('00dc', frame)]),
  ]);
}
