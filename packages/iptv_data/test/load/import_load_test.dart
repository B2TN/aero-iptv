@Tags(['load'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_data/src/adapters/m3u/m3u_source_adapter.dart';
import 'package:iptv_data/src/import/catalog_import_pipeline.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

/// Génère la playlist à la volée : le test ne la garde jamais en mémoire.
Stream<List<int>> playlist(int entries) async* {
  yield utf8.encode('#EXTM3U\n');
  for (var i = 0; i < entries; i += 1000) {
    final chunk = StringBuffer();
    for (var j = i; j < i + 1000 && j < entries; j++) {
      final quality = const ['FHD', 'HD', 'SD'][j % 3];
      chunk
        ..writeln(
          '#EXTINF:-1 tvg-id="c${j ~/ 3}.fr" '
          'tvg-logo="http://logo.example/c${j ~/ 3}.png" '
          'group-title="FRANCE ${j % 40}",FR: Chaîne ${j ~/ 3} $quality',
        )
        ..writeln('http://s.example:8080/live/user/password/$j.ts');
    }
    yield utf8.encode(chunk.toString());
    // Rend la main pour simuler un téléchargement réseau.
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('import de 300 000 entrées', () async {
    const entries = 300000;
    final directory = await Directory.systemTemp.createTemp('iptv_load');
    final file = File('${directory.path}/load.db');
    final db = AppDatabase(openAppDatabase(file));
    final client = MockClient.streaming((request, _) async {
      return http.StreamedResponse(playlist(entries), 200);
    });

    final repository = PlaylistRepositoryImpl(db, MemoryCredentialStore());
    final added = await repository.add(
      name: 'Charge',
      credentials: const M3uCredentials(
        playlistUrl: 'http://load.example/l.m3u',
      ),
    );
    final sourceId = (added as Ok<PlaylistSource>).value.id;

    final baselineRss = ProcessInfo.currentRss;
    final watch = Stopwatch()..start();
    final rss = <int>[];
    await for (final progress
        in CatalogImportPipeline(
          database: db,
          catalogAdapter: M3uSourceAdapter(client),
          epgAdapter: const FakeEpgAdapter(),
        ).run(
          sourceId,
          const M3uCredentials(playlistUrl: 'http://load.example/l.m3u'),
        )) {
      if (progress.processed % 50000 == 0) rss.add(ProcessInfo.currentRss);
    }
    watch.stop();

    final queryWatch = Stopwatch()..start();
    final liveTv = LiveTvRepositoryImpl(db);
    final group = (await liveTv.groups(sourceId, 'FR', grouped: true)).first;
    final page = await liveTv.channels(
      sourceId,
      'FR',
      group,
      const PageRequest(limit: 50, offset: 5000),
      grouped: true,
    );
    queryWatch.stop();

    final sizeMb = file.lengthSync() / (1024 * 1024);
    final samples = rss.map((value) => '${value ~/ (1024 * 1024)}').join(' ');
    // ignore: avoid_print
    print(
      'Import : ${watch.elapsed.inSeconds} s pour $entries entrées\n'
      'RSS avant import : ${baselineRss ~/ (1024 * 1024)} Mio\n'
      'RSS tous les 50 000 entrées (Mio) : $samples\n'
      'Pic RSS du processus : ${ProcessInfo.maxRss ~/ (1024 * 1024)} Mio\n'
      'Base : ${sizeMb.toStringAsFixed(0)} Mio\n'
      'Requête groupes + page profonde : ${queryWatch.elapsedMilliseconds} ms',
    );

    expect(page.items, hasLength(50));
    await db.close();
    await directory.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
