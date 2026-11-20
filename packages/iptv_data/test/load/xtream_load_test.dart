@Tags(['load'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_data/src/adapters/xtream/raw_entry.dart';
import 'package:iptv_data/src/adapters/xtream/xtream_source_adapter.dart';
import 'package:iptv_data/src/database/daos/catalog_merge_dao.dart';
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

/// Jour du panneau : à partir du deuxième, des films changent de format et
/// d'autres arrivent, comme d'un jour à l'autre chez un fournisseur.
var _day = 0;

/// Films changés et films ajoutés chaque jour.
const int _changedEvery = 1000;
const int _addedPerDay = 400;

/// Note recalculée par le panneau sur tous ses titres : l'application ne s'en
/// sert pas, mais le texte de chaque objet change.
var _volatile = 0;

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
    // Un film et ses traductions partagent leur affiche et leur identifiant
    // TMDb : ils forment une seule fiche.
    'stream_icon': 'https://image.tmdb.org/t/p/w500/m$title.jpg',
    'tmdb': '${100000 + title}',
    'added': '1700000000',
    'rating_5based': 3.5 + _volatile / 10,
    // Un format qui change est un vrai changement : l'application le lit.
    'container_extension': _day > 0 && i % _changedEvery == 0 ? 'mp4' : 'mkv',
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
    'rating': '${7 + _volatile / 10}',
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
      'get_vod_streams' => http.StreamedResponse(
        _list(_movies + _day * _addedPerDay, _movie),
        200,
      ),
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

      Future<int> sheetCount() async =>
          (await db
                  .customSelect(
                    'SELECT COUNT(DISTINCT grouping_key) AS n FROM movies '
                    'WHERE catalog_id = (SELECT active_catalog_id FROM sources)',
                  )
                  .getSingle())
              .read<int>('n');
      final importedSheets = await sheetCount();

      Future<Duration> sync() async {
        final clock = Stopwatch()..start();
        await CatalogImportPipeline(
          database: db,
          catalogAdapter: XtreamSourceAdapter(client),
          epgAdapter: const FakeEpgAdapter(),
        ).run(sourceId, _credentials).drain<void>();
        if (ProcessInfo.currentRss > peak) peak = ProcessInfo.currentRss;
        return clock.elapsed;
      }

      // Le lendemain : le même catalogue, comparé titre par titre. La
      // première synchronisation enregistre les empreintes, les suivantes
      // sautent tout ce qui n'a pas changé.
      final firstSync = await sync();
      final syncTotal = await sync();
      // Un jour ordinaire : quelques centaines de films changent ou
      // arrivent, et leurs fiches se recomposent.
      _day = 1;
      final changedSync = await sync();
      final sheets = await sheetCount();
      // Un panneau qui recalcule ses notes chaque jour.
      _volatile = 1;
      final volatileSync = await sync();
      // Le jour de la mise à jour vers les empreintes des seuls champs lus :
      // la base garde celles de tout le texte, de la version 1.
      final groups = categoriesHash({
        for (var i = 0; i < _categories; i++) '$i': 'FR | GROUPE $i',
      });
      final shown =
          (await db
                  .customSelect('SELECT active_catalog_id AS id FROM sources')
                  .getSingle())
              .read<int>('id');
      final merge = CatalogMergeDao(db);
      await merge.backfillHashes(shown, ContentKind.movie, [
        for (var i = 0; i < _movies + _addedPerDay; i++)
          ('x:m:$i', rawEntryHash(jsonEncode(_movie(i)), groups)),
      ]);
      await merge.backfillHashes(shown, ContentKind.series, [
        for (var i = 0; i < _series; i++)
          ('x:s:$i', rawEntryHash(jsonEncode(_show(i)), groups)),
      ]);
      await db.customStatement('UPDATE sources SET hash_version = 1');
      final transitionSync = await sync();
      // Un catalogue laissé par une version d'avant les empreintes.
      await db.customStatement('UPDATE movies SET source_hash = NULL');
      await db.customStatement('UPDATE series_entries SET source_hash = NULL');
      await db.customStatement('UPDATE sources SET live_hash = NULL');
      final upgradeSync = await sync();

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
        'Première synchronisation : ${firstSync.inSeconds} s\n'
        'Synchronisation du lendemain : '
        '${syncTotal.inMilliseconds / 1000} s\n'
        'Synchronisation avec ${_movies ~/ _changedEvery + _addedPerDay} '
        'films changés : ${changedSync.inMilliseconds / 1000} s\n'
        'Synchronisation, notes recalculées partout : '
        '${volatileSync.inMilliseconds / 1000} s\n'
        'Synchronisation de passage aux nouvelles empreintes : '
        '${transitionSync.inMilliseconds / 1000} s\n'
        'Fiches de films : $importedSheets, puis $sheets\n'
        'Synchronisation après mise à jour : ${upgradeSync.inSeconds} s\n'
        'Pic RSS : ${peak ~/ _mebibyte} Mio\n'
        'Base : ${sizeMb.toStringAsFixed(0)} Mio',
      );

      expect(series.items, hasLength(20));
      // Chaque film et ses trois traductions ne font qu'une fiche, même
      // regroupés pendant la synchronisation. Quelques titres générés
      // (« Film 1985 (1985) ») se confondent, par leur année.
      expect(importedSheets, closeTo(_movies ~/ _languages.length, 10));
      expect(sheets, importedSheets + _addedPerDay ~/ _languages.length);
      await db.close();
      await directory.delete(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
