@Tags(['load'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_data/src/adapters/xtream/xtream_source_adapter.dart';
import 'package:iptv_data/src/import/catalog_import_pipeline.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

const int _channels = 55000;
const int _movies = 200000;
const int _series = 46000;
const int _categories = 40;
const int _chunk = 500;
const int _mebibyte = 1024 * 1024;

/// Chaque titre existe en quatre langues, comme dans un vrai catalogue.
const List<String> _languages = ['FR', 'EN', 'DE', 'ES'];
const List<String> _articles = ['Le', 'The', 'Der', 'El'];

const String _plot =
    'Une famille découvre que la marée ne redescend plus, et que le village '
    'voisin a disparu des cartes. Chacun cherche une explication, puis une '
    'issue, alors que le phare se remet à tourner sans gardien.';

const XtreamCredentials _credentials = XtreamCredentials(
  serverUrl: 'http://panel.example:8080',
  username: 'essai',
  password: 'essai',
);

Map<String, Object?> _channel(int i) => {
  'num': i,
  'name': 'FR: Chaîne ${i ~/ 3} ${const ['FHD', 'HD', 'SD'][i % 3]}',
  'stream_type': 'live',
  'stream_id': i,
  'stream_icon': 'http://logo.example/c${i ~/ 3}.png',
  'epg_channel_id': 'c${i ~/ 3}.fr',
  'category_id': '${i % _categories}',
};

Map<String, Object?> _movie(int i) {
  final language = i % _languages.length;
  final title = i ~/ _languages.length;
  return {
    'num': i,
    'name':
        '${_languages[language]} - ${_articles[language]} Film $title '
        '(${1980 + title % 45})',
    'stream_type': 'movie',
    'stream_id': i,
    'stream_icon': 'http://image.example/m$title.jpg',
    'rating': '7.1',
    'added': '1700000000',
    'container_extension': 'mkv',
    'category_id': '${i % _categories}',
  };
}

Map<String, Object?> _show(int i) {
  final language = i % _languages.length;
  final title = i ~/ _languages.length;
  return {
    'num': i,
    'name': '${_languages[language]} - ${_articles[language]} Série $title',
    'series_id': i,
    'cover': 'http://image.example/s$title-$language.jpg',
    'plot': _plot,
    'cast': 'Ana Reis, Marc Aubin, Lise Tran, Omar Diallo',
    'genre': 'Drame',
    'releaseDate': '${1990 + title % 35}-01-01',
    'tmdb': '$title',
    'backdrop_path': ['http://image.example/b$title.jpg'],
    'category_id': '${i % _categories}',
  };
}

/// Génère la liste à la volée : le test ne la garde jamais en mémoire.
Stream<List<int>> _list(
  int count,
  Map<String, Object?> Function(int) item,
) async* {
  yield utf8.encode('[');
  for (var i = 0; i < count; i += _chunk) {
    final chunk = StringBuffer();
    for (var j = i; j < i + _chunk && j < count; j++) {
      if (j > 0) chunk.write(',');
      chunk.write(jsonEncode(item(j)));
    }
    yield utf8.encode(chunk.toString());
    // Rend la main pour simuler un téléchargement réseau.
    await Future<void>.delayed(Duration.zero);
  }
  yield utf8.encode(']');
}

http.StreamedResponse _json(Object? body) =>
    http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200);

http.StreamedResponse _panel(http.BaseRequest request) =>
    switch (request.url.queryParameters['action']) {
      null => _json({
        'user_info': {'auth': 1, 'status': 'Active'},
      }),
      'get_live_streams' => http.StreamedResponse(
        _list(_channels, _channel),
        200,
      ),
      'get_vod_streams' => http.StreamedResponse(_list(_movies, _movie), 200),
      'get_series' => http.StreamedResponse(_list(_series, _show), 200),
      _ => _json([
        for (var i = 0; i < _categories; i++)
          {'category_id': '$i', 'category_name': 'FR | GROUPE $i'},
      ]),
    };

void main() {
  test(
    'import d un catalogue Xtream de 300 000 titres, étape par étape',
    () async {
      final directory = await Directory.systemTemp.createTemp('iptv_xtream');
      final file = File('${directory.path}/load.db');
      final db = AppDatabase(openAppDatabase(file));
      final vault = MemoryCredentialStore();
      final client = MockClient.streaming(
        (request, _) async => _panel(request),
      );
      final added = await PlaylistRepositoryImpl(
        db,
        vault,
      ).add(name: 'Charge', credentials: _credentials);
      final sourceId = (added as Ok<PlaylistSource>).value.id;

      final watch = Stopwatch()..start();
      final report = StringBuffer();
      var step = 'connexion';
      var since = Duration.zero;
      var peak = ProcessInfo.currentRss;
      void close(String next) {
        final now = watch.elapsed;
        report.writeln(
          '${step.padRight(22)} ${(now - since).inMilliseconds} ms',
        );
        step = next;
        since = now;
      }

      await for (final progress in CatalogImportPipeline(
        database: db,
        catalogAdapter: XtreamSourceAdapter(client),
        epgAdapter: const FakeEpgAdapter(),
      ).run(sourceId, _credentials)) {
        final rss = ProcessInfo.currentRss;
        if (rss > peak) peak = rss;
        final name = switch (progress.stage) {
          ImportStage.catalog => 'réception ${progress.section?.name}',
          ImportStage.indexing => 'préparation',
          ImportStage.epg => 'guide',
          _ => step,
        };
        if (name != step) close(name);
      }
      close('fin');
      final total = watch.elapsed;

      Future<void> timed(String name, Future<Object?> Function() query) async {
        final clock = Stopwatch()..start();
        await query();
        report.writeln('${name.padRight(22)} ${clock.elapsedMilliseconds} ms');
      }

      final catalog = CatalogRepositoryImpl(db, vault, client);
      final search = SearchRepositoryImpl(db);
      final keys = {
        for (var i = 0; i < 250; i++) GroupingKey.of('Le Film ${i * 37}'),
        for (var i = 0; i < 250; i++) GroupingKey.of('La Série ${i * 11}'),
      };
      const row = PageRequest(limit: 20);
      report.writeln('--- requêtes de l accueil');
      await timed('films', () => catalog.movies(sourceId, row));
      await timed(
        'films en français',
        () => catalog.moviesInLanguage(sourceId, 'fr', row),
      );
      await timed(
        'séries regroupées',
        () => catalog.series(sourceId, row, grouped: true, language: 'fr'),
      );
      await timed(
        'films des tendances',
        () => catalog.moviesByTitleKeys(sourceId, keys),
      );
      await timed(
        'séries des tendances',
        () => catalog.seriesByTitleKeys(
          sourceId,
          keys,
          grouped: true,
          language: 'fr',
        ),
      );
      await timed(
        'recherche',
        () => search.search(sourceId, 'film 12', row, language: 'fr'),
      );

      final series = await catalog.series(
        sourceId,
        row,
        grouped: true,
        language: 'fr',
      );
      final sizeMb = file.lengthSync() / _mebibyte;
      // ignore: avoid_print
      print(
        '$report'
        'Import complet : ${total.inSeconds} s\n'
        'Pic RSS : ${peak ~/ _mebibyte} Mio\n'
        'Base : ${sizeMb.toStringAsFixed(0)} Mio',
      );

      expect(series.items, hasLength(20));
      await db.close();
      await directory.delete(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
