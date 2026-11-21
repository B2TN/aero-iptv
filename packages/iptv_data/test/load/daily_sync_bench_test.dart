// Banc de la synchronisation quotidienne, au plus près d'un vrai fournisseur :
// le catalogue de l'utilisateur type (55 000 chaînes, 200 000 films, 46 000
// séries), un guide XMLTV de 4 000 chaînes sur trois jours, un débit limité
// et un panneau qui met du temps à préparer chaque liste.
//
// À lancer depuis `packages/iptv_data` :
//
//   dart test --run-skipped -t load test/load/daily_sync_bench_test.dart
//
// `AERO_BENCH_MBITS` change le débit (25 Mbit/s par défaut), et
// `AERO_BENCH_WAIT_MS` l'attente avant le premier octet d'une liste (1500 ms).
@Tags(['load'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_data/src/adapters/xtream/xtream_source_adapter.dart';
import 'package:iptv_data/src/epg/xtream_epg_adapter.dart';
import 'package:iptv_data/src/import/catalog_import_pipeline.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

const int _channels = 55000;
const int _movies = 200000;
const int _series = 46000;
const int _categories = 40;
const int _guideChannels = 4000;
const int _guideHours = 72;
const int _chunk = 500;

final int _bytesPerSecond =
    (int.tryParse(Platform.environment['AERO_BENCH_MBITS'] ?? '') ?? 25) *
    1000000 ~/
    8;
final Duration _firstByte = Duration(
  milliseconds:
      int.tryParse(Platform.environment['AERO_BENCH_WAIT_MS'] ?? '') ?? 1500,
);

/// Jour du panneau : le lendemain, des films changent ou arrivent, quelques
/// séries reçoivent un épisode, une chaîne change de nom et le guide avance
/// d'un jour.
var _day = 0;

/// Octets servis depuis le début du jour : ce qui a transité par le réseau.
var _served = 0;

const XtreamCredentials _credentials = XtreamCredentials(
  serverUrl: 'http://panel.example:8080',
  username: 'banc',
  password: 'banc',
);

const String _plot =
    'Une famille découvre que la marée ne redescend plus, et que le village '
    'voisin a disparu des cartes.';

Map<String, Object?> _channel(int i) => {
  'num': i,
  'name':
      'FR: Chaîne ${i ~/ 3} ${const ['FHD', 'HD', 'SD'][i % 3]}'
      '${_day > 0 && i == 7 ? ' (événement)' : ''}',
  'stream_type': 'live',
  'stream_id': i,
  'stream_icon': 'http://logo.example/c${i ~/ 3}.png',
  'epg_channel_id': 'c${i ~/ 3}.fr',
  'added': '1700000000',
  'category_id': '${i % _categories}',
};

Map<String, Object?> _movie(int i) {
  const languages = ['FR', 'EN', 'DE', 'ES'];
  final title = i ~/ languages.length;
  return {
    'num': i,
    'name': '${languages[i % 4]} - Film $title (${1980 + title % 45})',
    'stream_type': 'movie',
    'stream_id': i,
    'stream_icon': 'https://image.tmdb.org/t/p/w500/m$title.jpg',
    'rating': '7.1',
    'rating_5based': 3.5,
    'tmdb': '${100000 + title}',
    'added': '${1700000000 + i}',
    'is_adult': 0,
    'container_extension': _day > 0 && i % 200 == 0 ? 'mp4' : 'mkv',
    'custom_sid': null,
    'direct_source': '',
    'category_id': '${i % _categories}',
  };
}

Map<String, Object?> _show(int i) {
  const languages = ['FR', 'EN', 'DE', 'ES'];
  final title = i ~/ languages.length;
  return {
    'num': i,
    'name': '${languages[i % 4]} - Série $title',
    'series_id': i,
    'cover': 'http://image.example/s$title.jpg',
    'plot': _plot,
    'cast': 'Ana Reis, Marc Aubin',
    'genre': 'Drame',
    'releaseDate': '${1990 + title % 35}-01-01',
    'tmdb': '$title',
    'last_modified': '${1700000000 + (_day > 0 && i % 1000 == 0 ? 1 : 0)}',
    'rating': '7',
    'backdrop_path': ['http://image.example/b$title.jpg'],
    'category_id': '${i % _categories}',
  };
}

/// Livre [body] au débit du banc, après l'attente du panneau.
Stream<List<int>> _throttled(Stream<List<int>> body, Duration wait) async* {
  await Future<void>.delayed(wait);
  final clock = Stopwatch()..start();
  var sent = 0;
  await for (final chunk in body) {
    sent += chunk.length;
    _served += chunk.length;
    yield chunk;
    final due = Duration(microseconds: sent * 1000000 ~/ _bytesPerSecond);
    final ahead = due - clock.elapsed;
    // L'horloge de Windows avance par pas de 15 ms : on dort par paquets.
    if (ahead > const Duration(milliseconds: 20)) {
      await Future<void>.delayed(ahead);
    }
  }
}

Stream<List<int>> _list(
  int count,
  Map<String, Object?> Function(int) item,
) async* {
  yield utf8.encode('[');
  for (var i = 0; i < count; i += _chunk) {
    final chunk = StringBuffer();
    for (var j = i; j < math.min(i + _chunk, count); j++) {
      if (j > 0) chunk.write(',');
      chunk.write(jsonEncode(item(j)));
    }
    yield utf8.encode(chunk.toString());
  }
  yield utf8.encode(']');
}

String _xmltvTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${time.year}${two(time.month)}${two(time.day)}'
      '${two(time.hour)}${two(time.minute)}00 +0000';
}

/// Guide de trois jours, qui commence la veille au soir.
Stream<List<int>> _guide() async* {
  final now = DateTime.now().toUtc();
  final origin = DateTime.utc(now.year, now.month, now.day - 1, 18);
  yield utf8.encode('<?xml version="1.0" encoding="UTF-8"?>\n<tv>\n');
  final channels = StringBuffer();
  for (var c = 0; c < _guideChannels; c++) {
    channels.write(
      '<channel id="c$c.fr"><display-name>Chaîne $c</display-name></channel>\n',
    );
  }
  yield utf8.encode(channels.toString());
  for (var c = 0; c < _guideChannels; c += 20) {
    final chunk = StringBuffer();
    for (var k = c; k < math.min(c + 20, _guideChannels); k++) {
      for (var h = 0; h < _guideHours; h++) {
        final start = origin.add(Duration(hours: h));
        chunk.write(
          '<programme start="${_xmltvTime(start)}" '
          'stop="${_xmltvTime(start.add(const Duration(hours: 1)))}" '
          'channel="c$k.fr"><title lang="fr">Émission $h de la chaîne $k'
          '</title><desc lang="fr">$_plot</desc></programme>\n',
        );
      }
    }
    yield utf8.encode(chunk.toString());
  }
  yield utf8.encode('</tv>\n');
}

http.StreamedResponse _small(Object? body) => http.StreamedResponse(
  _throttled(
    Stream.value(utf8.encode(jsonEncode(body))),
    const Duration(milliseconds: 150),
  ),
  200,
);

http.StreamedResponse _panel(http.BaseRequest request) {
  if (request.url.path.endsWith('xmltv.php')) {
    return http.StreamedResponse(_throttled(_guide(), _firstByte), 200);
  }
  return switch (request.url.queryParameters['action']) {
    null => _small({
      'user_info': {'auth': 1, 'status': 'Active'},
    }),
    'get_live_streams' => http.StreamedResponse(
      _throttled(_list(_channels, _channel), _firstByte),
      200,
    ),
    'get_vod_streams' => http.StreamedResponse(
      _throttled(_list(_movies + _day * 400, _movie), _firstByte),
      200,
    ),
    'get_series' => http.StreamedResponse(
      _throttled(_list(_series, _show), _firstByte),
      200,
    ),
    _ => _small([
      for (var i = 0; i < _categories; i++)
        {'category_id': '$i', 'category_name': 'FR | GROUPE $i'},
    ]),
  };
}

void main() {
  test('synchronisation quotidienne, étape par étape', () async {
    final directory = await Directory.systemTemp.createTemp('iptv_banc');
    final file = File('${directory.path}/banc.db');
    final db = AppDatabase(openAppDatabase(file));
    final vault = MemoryCredentialStore();
    final client = MockClient.streaming((request, _) async => _panel(request));
    final playlists = PlaylistRepositoryImpl(db, vault);
    final added = await playlists.add(name: 'Banc', credentials: _credentials);
    final sourceId = (added as Ok<PlaylistSource>).value.id;

    Future<String> run(String name) async {
      _served = 0;
      final clock = Stopwatch()..start();
      await CatalogImportPipeline(
        database: db,
        catalogAdapter: XtreamSourceAdapter(client),
        epgAdapter: XtreamEpgAdapter(client),
      ).run(sourceId, _credentials).drain<void>();
      final total = clock.elapsed;
      final source = (await playlists.watchSources().first).single;
      final steps = [
        for (final step in source.lastSyncReport!.steps)
          '  ${step.phase.name.padRight(11)}'
              '${(step.duration.inMilliseconds / 1000).toStringAsFixed(1).padLeft(6)} s'
              '  (${step.received} reçus, ${step.changed} modifiés)',
      ];
      return '$name : ${(total.inMilliseconds / 1000).toStringAsFixed(1)} s, '
          '${_served ~/ (1024 * 1024)} Mio téléchargés\n${steps.join('\n')}';
    }

    final report = StringBuffer()
      ..writeln(
        'Débit ${_bytesPerSecond * 8 ~/ 1000000} Mbit/s, '
        'attente du panneau ${_firstByte.inMilliseconds} ms',
      )
      ..writeln(await run('Import complet'))
      ..writeln(await run('Synchronisation suivante, rien de changé'));
    _day = 1;
    report.writeln(await run('Lendemain'));
    // Un jour où le guide ne couvre plus la journée : il est relu.
    await db.customStatement('DELETE FROM epg_programmes');
    report.writeln(await run('Lendemain, guide relu'));
    // ignore: avoid_print
    print(report);
    await db.close();
    await directory.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
