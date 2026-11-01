import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/src/epg/epg_source_adapter.dart';
import 'package:iptv_data/src/epg/xmltv_epg_adapter.dart';
import 'package:iptv_data/src/epg/xmltv_event_parser.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

const String guide = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="TF1.fr"><display-name>TF1</display-name></channel>
  <channel id="other.fr"><display-name>Autre</display-name></channel>
  <channel id="France2.fr">
    <display-name>FR: France 2 HD</display-name>
  </channel>
  <programme start="20261031200000 +0100" stop="20261031210000 +0100" channel="TF1.fr">
    <title lang="fr">Le &amp; journal</title>
    <title lang="en">The news</title>
    <desc lang="fr"><![CDATA[Résumé <détaillé>]]></desc>
  </programme>
  <programme start="20261031200000 +0100" stop="20261031210000 +0100" channel="other.fr">
    <title>Hors playlist</title>
  </programme>
  <programme start="20261031200000 +0100" stop="20261031210000 +0100" channel="France2.fr">
    <title>Par le nom</title>
  </programme>
  <programme start="20270101000000 +0000" stop="20270101010000 +0000" channel="TF1.fr">
    <title>Trop lointain</title>
  </programme>
  <programme start="20261031200000 +0100" stop="20261031210000 +0100" channel="TF1.fr">
    <title/>
  </programme>
</tv>
''';

EpgRequest requestFor(Set<String> keys) => EpgRequest(
  credentials: const M3uCredentials(
    playlistUrl: 'http://s/l.m3u',
    epgUrl: 'http://e/guide.xml',
  ),
  knownKeys: keys,
  from: DateTime.utc(2026, 10, 31),
  to: DateTime.utc(2026, 11, 2),
);

void main() {
  group('parseXmltvTimestamp', () {
    test('applique le décalage horaire', () {
      expect(
        parseXmltvTimestamp('20261031203000 +0100'),
        DateTime.utc(2026, 10, 31, 19, 30),
      );
      expect(
        parseXmltvTimestamp('20261031203000 -0230'),
        DateTime.utc(2026, 10, 31, 23),
      );
    });

    test('accepte l absence de secondes et de décalage', () {
      expect(
        parseXmltvTimestamp('202610312030'),
        DateTime.utc(2026, 10, 31, 20, 30),
      );
    });

    test('retourne null pour une date invalide', () {
      expect(parseXmltvTimestamp('demain'), isNull);
      expect(parseXmltvTimestamp(null), isNull);
    });
  });

  group('parseXmltv', () {
    test('lit chaînes et émissions', () async {
      final items = await parseXmltv(Stream.value(guide)).toList();
      final channels = items.whereType<XmltvChannel>().toList();
      final programmes = items.whereType<XmltvProgramme>().toList();

      expect(channels, hasLength(3));
      expect(channels.first.displayNames, ['TF1']);

      final first = programmes.first;
      expect(first.title, 'Le & journal');
      expect(first.description, 'Résumé <détaillé>');
      expect(first.start, DateTime.utc(2026, 10, 31, 19));
    });

    test('ignore une émission sans titre', () async {
      final items = await parseXmltv(Stream.value(guide)).toList();
      expect(items.whereType<XmltvProgramme>(), hasLength(4));
    });

    test('résiste à un découpage arbitraire du flux', () async {
      final chunks = [
        for (var i = 0; i < guide.length; i += 17)
          guide.substring(i, i + 17 > guide.length ? guide.length : i + 17),
      ];
      final items = await parseXmltv(Stream.fromIterable(chunks)).toList();
      expect(items.whereType<XmltvProgramme>().first.title, 'Le & journal');
    });
  });

  group('XmltvEpgAdapter', () {
    Future<List<EpgProgramme>> fetch(http.Response response) async {
      final adapter = XmltvEpgAdapter(MockClient((_) async => response));
      final batches = await adapter
          .fetch(requestFor({'tf1.fr', 'france2'}))
          .toList();
      return batches.expand((batch) => batch).toList();
    }

    test('filtre sur le catalogue et la fenêtre', () async {
      final programmes = await fetch(
        http.Response.bytes(utf8.encode(guide), 200),
      );
      expect(programmes.map((p) => p.title), ['Le & journal', 'Par le nom']);
    });

    test('rapproche une chaîne par son nom affiché', () async {
      final programmes = await fetch(
        http.Response.bytes(utf8.encode(guide), 200),
      );
      expect(programmes.last.epgKey, 'france2');
    });

    test('décompresse un guide .xml.gz', () async {
      final compressed = gzip.encode(utf8.encode(guide));
      final programmes = await fetch(http.Response.bytes(compressed, 200));
      expect(programmes, hasLength(2));
    });

    test('ne fait rien sans adresse de guide', () async {
      final adapter = XmltvEpgAdapter(
        MockClient((_) async => fail('aucune requête attendue')),
      );
      final request = EpgRequest(
        credentials: const M3uCredentials(playlistUrl: 'http://s/l.m3u'),
        knownKeys: const {},
        from: DateTime.utc(2026),
        to: DateTime.utc(2027),
      );
      expect(await adapter.fetch(request).toList(), isEmpty);
    });
  });
}
