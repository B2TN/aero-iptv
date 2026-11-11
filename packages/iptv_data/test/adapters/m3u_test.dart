import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/src/adapters/catalog_batch.dart';
import 'package:iptv_data/src/adapters/m3u/m3u_entry_mapper.dart';
import 'package:iptv_data/src/adapters/m3u/m3u_line_parser.dart';
import 'package:iptv_data/src/adapters/m3u/m3u_source_adapter.dart';
import 'package:iptv_data/src/adapters/playlist_source_adapter.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

M3uEntry? parseOne(List<String> lines) {
  final parser = M3uLineParser();
  M3uEntry? result;
  for (final line in lines) {
    result = parser.accept(line) ?? result;
  }
  return result;
}

void main() {
  group('M3uLineParser', () {
    test('lit les attributs et le titre', () {
      final entry = parseOne([
        '#EXTINF:-1 tvg-id="tf1.fr" tvg-logo="http://l/a.png" group-title="FR",TF1 HD',
        'http://s/1.ts',
      ])!;
      expect(entry.title, 'TF1 HD');
      expect(entry.url, 'http://s/1.ts');
      expect(entry.attributes['tvg-id'], 'tf1.fr');
      expect(entry.group, 'FR');
    });

    test('accepte une virgule dans un attribut', () {
      final entry = parseOne([
        '#EXTINF:-1 tvg-name="Bonjour, le monde" group-title="A, B",Le titre',
        'http://s/1.ts',
      ])!;
      expect(entry.title, 'Le titre');
      expect(entry.attributes['tvg-name'], 'Bonjour, le monde');
      expect(entry.group, 'A, B');
    });

    test('accepte une virgule dans le titre', () {
      final entry = parseOne(['#EXTINF:-1,Paris, je t aime', 'http://s/1.ts'])!;
      expect(entry.title, 'Paris, je t aime');
    });

    test('accepte les attributs sans guillemets ou avec apostrophes', () {
      final entry = parseOne([
        "#EXTINF:0 tvg-id=abc tvg-logo='http://l/a.png',Nom",
        'http://s/1.ts',
      ])!;
      expect(entry.attributes['tvg-id'], 'abc');
      expect(entry.attributes['tvg-logo'], 'http://l/a.png');
    });

    test('lit #EXTGRP et #EXTVLCOPT', () {
      final entry = parseOne([
        '#EXTINF:-1,Nom',
        '#EXTGRP:Sports',
        '#EXTVLCOPT:http-user-agent=Agent/1.0',
        '#EXTVLCOPT:http-referrer=http://r.example/',
        'http://s/1.ts',
      ])!;
      expect(entry.group, 'Sports');
      expect(entry.userAgent, 'Agent/1.0');
      expect(entry.referrer, 'http://r.example/');
    });

    test('sépare les en-têtes ajoutés à l URL', () {
      final entry = parseOne([
        '#EXTINF:-1,Nom',
        'http://s/1.ts|User-Agent=Agent%2F1.0&Referer=http://r.example/',
      ])!;
      expect(entry.url, 'http://s/1.ts');
      expect(entry.userAgent, 'Agent/1.0');
      expect(entry.referrer, 'http://r.example/');
    });

    test('lit le guide de l en-tête et ignore le BOM', () {
      final parser = M3uLineParser()
        ..accept('﻿#EXTM3U x-tvg-url="http://e/g.xml"');
      expect(parser.epgUrl, 'http://e/g.xml');
      expect(parser.sawPlaylistContent, isTrue);
    });

    test('ne propage pas les attributs à l entrée suivante', () {
      final parser = M3uLineParser();
      parser.accept('#EXTINF:-1,A');
      parser.accept('#EXTGRP:Sports');
      parser.accept('http://s/1.ts');
      parser.accept('#EXTINF:-1,B');
      expect(parser.accept('http://s/2.ts')!.group, isNull);
    });

    test('ignore une URL sans #EXTINF', () {
      expect(M3uLineParser().accept('http://s/1.ts'), isNull);
    });
  });

  group('M3uEntryMapper', () {
    const mapper = M3uEntryMapper();

    CatalogEntry? map(String title, String url) =>
        mapper.map(M3uEntry(title: title, url: url, attributes: const {}));

    test('classe selon le chemin Xtream', () {
      expect(map('A', 'http://s/live/u/p/1.ts'), isA<LiveEntry>());
      expect(map('A', 'http://s/movie/u/p/1.mkv'), isA<MovieEntry>());
      expect(map('A', 'http://s/series/u/p/1.mkv'), isA<EpisodeEntry>());
    });

    test('classe selon le nom et l extension', () {
      expect(map('Lost S01E01', 'http://s/a.mkv'), isA<EpisodeEntry>());
      expect(map('Inception', 'http://s/a.mp4?t=1'), isA<MovieEntry>());
      expect(map('TF1', 'http://s/a.m3u8'), isA<LiveEntry>());
    });

    test('écarte les lignes de séparation', () {
      expect(map('#### FRANCE ####', 'http://s/live/1.ts'), isNull);
    });
  });

  group('M3uSourceAdapter', () {
    const credentials = M3uCredentials(
      playlistUrl: 'http://s.example/list.m3u',
    );

    test('traduit une playlist complète', () async {
      final body = File('test/fixtures/sample.m3u').readAsStringSync();
      final client = MockClient((_) async => http.Response(body, 200));
      final batches = await M3uSourceAdapter(
        client,
      ).fetch(credentials).toList();

      final entries = batches.expand((batch) => batch.entries).toList();
      expect(entries.whereType<LiveEntry>(), hasLength(4));
      expect(entries.whereType<MovieEntry>(), hasLength(1));
      expect(entries.whereType<EpisodeEntry>(), hasLength(5));
      expect(batches.first.discoveredEpgUrl, 'http://epg.example/guide.xml.gz');
    });

    test('rejette une page HTML', () async {
      final client = MockClient(
        (_) async => http.Response('<html>Erreur</html>', 200),
      );
      expect(
        M3uSourceAdapter(client).fetch(credentials).toList(),
        throwsA(isA<ParseFailure>()),
      );
    });

    test('traduit un refus du serveur', () async {
      final client = MockClient((_) async => http.Response('', 403));
      expect(
        M3uSourceAdapter(client).fetch(credentials).toList(),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('ne divulgue pas l URL dans une erreur réseau', () async {
      final client = MockClient(
        (_) async => throw http.ClientException(
          'refusé',
          Uri.parse('http://s/u/secret/list.m3u'),
        ),
      );
      await expectLater(
        M3uSourceAdapter(client).fetch(credentials).toList(),
        throwsA(
          isA<NetworkFailure>().having(
            (failure) => failure.toString(),
            'message',
            isNot(contains('secret')),
          ),
        ),
      );
    });
  });
}
