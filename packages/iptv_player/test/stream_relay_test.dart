import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/src/stream_relay.dart';
import 'package:test/test.dart';

import 'support/one_connection_panel.dart';

const int _mebibyte = 1024 * 1024;

/// Fichier dont chaque octet dépend de sa position : un mauvais décalage se voit.
Uint8List _buildFile(int size) {
  final bytes = Uint8List(size);
  for (var i = 0; i < size; i++) {
    bytes[i] = (i ~/ 256 + i) & 0xFF;
  }
  return bytes;
}

Future<Uint8List> _take(Stream<List<int>> answer, int count) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in answer) {
    bytes.add(chunk);
    if (bytes.length >= count) break;
  }
  return Uint8List.sublistView(bytes.takeBytes(), 0, count);
}

void main() {
  final file = _buildFile(40 * _mebibyte);
  late StreamRelay relay;
  late HttpClient client;

  setUp(() async {
    relay = await StreamRelay.start(windowBytes: 6 * _mebibyte);
    client = HttpClient();
    addTearDown(() {
      client.close(force: true);
      relay.close();
    });
  });

  Future<HttpClientResponse> read(String address, {int? from}) async {
    final request = await client.getUrl(Uri.parse(address));
    if (from != null) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
    }
    return request.close();
  }

  Future<String> relayOf(OneConnectionPanel panel, {bool live = false}) =>
      relay.addressOf(ResolvedStream(url: panel.url), live: live);

  Future<OneConnectionPanel> startPanel({
    Duration releaseDelay = Duration.zero,
    bool refuseAll = false,
    bool announcesSize = true,
  }) async {
    final panel = await OneConnectionPanel.start(
      file,
      releaseDelay: releaseDelay,
      refuseAll: refuseAll,
      announcesSize: announcesSize,
    );
    addTearDown(panel.close);
    return panel;
  }

  test('n expose ni le compte ni le mot de passe', () async {
    final address = await relay.addressOf(
      const ResolvedStream(url: 'http://s.example/movie/compte/secret/1.mkv'),
    );

    expect(address, startsWith('http://127.0.0.1:'));
    expect(address, endsWith('.mkv'));
    expect(address, isNot(contains('compte')));
    expect(address, isNot(contains('secret')));
  });

  test('laisse au lecteur les listes HLS et les adresses locales', () {
    expect(StreamRelay.canCarry('http://s/live/a/b/1.ts'), isTrue);
    expect(StreamRelay.canCarry('https://s/movie/a/b/1.mkv'), isTrue);
    expect(StreamRelay.canCarry('http://s/live/a/b/1.m3u8'), isFalse);
    expect(StreamRelay.canCarry('http://s/1.M3U8?token=a'), isFalse);
    expect(StreamRelay.canCarry('http://s/1.mpd'), isFalse);
    expect(StreamRelay.canCarry('rtsp://s/1'), isFalse);
    expect(StreamRelay.canCarry('C:/films/1.mkv'), isFalse);
  });

  test('transmet le début et les reprises du fichier', () async {
    final panel = await startPanel();
    final address = await relayOf(panel);

    final answer = await read(address, from: 1000);
    final first = await _take(answer, 5000);

    expect(answer.statusCode, HttpStatus.partialContent);
    expect(answer.contentLength, file.length - 1000);
    expect(
      answer.headers.value(HttpHeaders.contentRangeHeader),
      'bytes 1000-${file.length - 1}/${file.length}',
    );
    expect(answer.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
    expect(first, file.sublist(1000, 6000));
    expect(panel.ranges.single, 'bytes=1000-');
  });

  test(
    'un retour en arrière dans la fenêtre ne rouvre aucune connexion',
    () async {
      final panel = await startPanel(releaseDelay: const Duration(seconds: 30));
      final address = await relayOf(panel);

      await _take(await read(address), 3 * _mebibyte);
      final back = await read(address, from: 2 * _mebibyte);
      final bytes = await _take(back, 2 * _mebibyte);

      expect(back.statusCode, HttpStatus.partialContent);
      expect(bytes, file.sublist(2 * _mebibyte, 4 * _mebibyte));
      expect(panel.ranges, hasLength(1));
      expect(panel.refused, 0);
    },
  );

  test('un petit saut en avant se lit à la suite', () async {
    final panel = await startPanel(releaseDelay: const Duration(seconds: 30));
    final address = await relayOf(panel);

    await _take(await read(address), _mebibyte);
    final from = 7 * _mebibyte;
    final ahead = await read(address, from: from);
    final bytes = await _take(ahead, _mebibyte);

    expect(bytes, file.sublist(from, from + _mebibyte));
    expect(panel.ranges, hasLength(1));
  });

  test('coupe la connexion en cours avant d en ouvrir une autre', () async {
    final panel = await startPanel();
    final address = await relayOf(panel);

    final first = await read(address);
    expect(first.statusCode, HttpStatus.ok);
    final from = 30 * _mebibyte;
    final second = await read(address, from: from);

    expect(second.statusCode, HttpStatus.partialContent);
    expect(await _take(second, 1000), file.sublist(from, from + 1000));
    expect(panel.ranges, hasLength(2));
    expect(panel.mostActive, 1);
  });

  test('attend qu un panneau lent libère la connexion coupée', () async {
    final panel = await startPanel(
      releaseDelay: const Duration(milliseconds: 1200),
    );
    final address = await relayOf(panel);

    await read(address);
    final second = await read(address, from: 30 * _mebibyte);

    expect(second.statusCode, HttpStatus.partialContent);
    expect(panel.refused, greaterThan(0));
  });

  test('un compte vraiment occupé est refusé sans attente', () async {
    final panel = await startPanel(refuseAll: true);
    final address = await relayOf(panel);

    final clock = Stopwatch()..start();
    final answer = await read(address);

    expect(answer.statusCode, 458);
    expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
    expect(panel.refused, 1);
  });

  test('ne lit pas le film plus vite que le lecteur', () async {
    final panel = await startPanel();
    final address = await relayOf(panel);

    final answer = await read(address);
    await Future<void>.delayed(const Duration(seconds: 1));

    // Deux mégaoctets de lecture anticipée, et ce que retiennent les sockets.
    expect(panel.sent, lessThan(12 * _mebibyte));
    expect(await _take(answer, 1000), file.sublist(0, 1000));
  });

  test('reprend seul si le serveur coupe au milieu du fichier', () async {
    final panel = await startPanel();
    final address = await relayOf(panel);

    final answer = await read(address);
    final bytes = BytesBuilder(copy: false);
    var cut = false;
    await for (final chunk in answer) {
      bytes.add(chunk);
      if (!cut && bytes.length > 3 * _mebibyte) {
        cut = true;
        panel.dropConnections();
      }
    }

    expect(bytes.takeBytes(), file);
    expect(panel.ranges, hasLength(greaterThan(1)));
    expect(panel.mostActive, 1);
  });

  test('un serveur qui ne livre plus rien écourte le fichier', () async {
    final panel = await startPanel();
    final address = await relayOf(panel);

    final answer = await read(address);
    panel.refuseEverything();
    final received = Completer<void>();
    var bytes = 0;
    answer.listen(
      (chunk) {
        bytes += chunk.length;
        if (bytes > _mebibyte && !received.isCompleted) received.complete();
      },
      onError: (Object _) {},
      onDone: () {
        if (!received.isCompleted) received.complete();
      },
      cancelOnError: true,
    );
    await received.future;
    panel.dropConnections();

    await Future<void>.delayed(const Duration(seconds: 1));
    expect(bytes, lessThan(file.length));
    expect(panel.active, 0);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('applique les en-têtes du flux', () async {
    final panel = await startPanel();
    final address = await relay.addressOf(
      ResolvedStream(url: panel.url, headers: const {'User-Agent': 'Lecteur'}),
    );

    await read(address);

    expect(panel.identities.single, 'Lecteur');
  });

  test('suit une redirection du panneau', () async {
    final panel = await startPanel();
    final front = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => front.close(force: true));
    front.listen((request) {
      unawaited(request.response.redirect(Uri.parse(panel.url)));
    });
    final address = await relay.addressOf(
      ResolvedStream(url: 'http://127.0.0.1:${front.port}/movie/a/b/1.mp3'),
    );

    final answer = await read(address);

    expect(answer.statusCode, HttpStatus.ok);
  });

  test('un serveur injoignable répond une erreur au lecteur', () async {
    final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close(force: true);
    final address = await relay.addressOf(
      ResolvedStream(url: 'http://127.0.0.1:$port/movie/a/b/1.mp3'),
    );

    final answer = await read(address);
    await answer.transform(utf8.decoder).join();

    expect(answer.statusCode, HttpStatus.badGateway);
  });

  test('rendre le flux libère la connexion sans arrêter le relais', () async {
    final panel = await startPanel();
    final address = await relayOf(panel);

    await read(address);
    expect(panel.active, 1);

    relay.release();
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(panel.active, 0);

    final again = await read(await relayOf(panel));
    expect(again.statusCode, HttpStatus.ok);
  });

  test('fermer le relais libère la connexion du panneau', () async {
    final panel = await startPanel();
    final address = await relayOf(panel);

    await read(address);
    expect(panel.active, 1);

    relay.close();
    await Future<void>.delayed(const Duration(seconds: 1));

    expect(panel.active, 0);
  });

  group('direct', () {
    test('n envoie aucune position au serveur', () async {
      final panel = await startPanel();
      final address = await relayOf(panel, live: true);

      await read(address, from: 0);

      expect(panel.ranges.single, isNull);
    });

    test('n annonce ni taille ni reprise au lecteur', () async {
      final panel = await startPanel();
      final address = await relayOf(panel, live: true);

      final answer = await read(address, from: 0);

      expect(answer.statusCode, HttpStatus.ok);
      expect(answer.contentLength, -1);
      expect(answer.headers.value(HttpHeaders.acceptRangesHeader), isNull);
      expect(await _take(answer, 1000), file.sublist(0, 1000));
    });

    test('garde une seule connexion quand mpv recommence', () async {
      final panel = await startPanel();
      final address = await relayOf(panel, live: true);

      await read(address);
      await read(address);

      expect(panel.mostActive, 1);
    });

    test('une chaîne qui se réveille lentement finit par répondre', () async {
      final panel = await startPanel();
      panel.answerDelay = const Duration(seconds: 7);
      final address = await relayOf(panel, live: true);

      final answer = await read(address);

      expect(answer.statusCode, HttpStatus.ok);
      expect(await _take(answer, 1000), file.sublist(0, 1000));
    });

    test('une liste sans extension revient au lecteur', () async {
      final front = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => front.close(force: true));
      front.listen((request) {
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/vnd.apple.mpegurl',
        );
        request.response.write('#EXTM3U');
        unawaited(request.response.close());
      });
      final url = 'http://127.0.0.1:${front.port}/chaine/1';
      final address = await relay.addressOf(
        ResolvedStream(url: url),
        live: true,
      );

      final request = await client.getUrl(Uri.parse(address));
      request.followRedirects = false;
      final answer = await request.close();

      expect(answer.statusCode, HttpStatus.movedTemporarily);
      expect(answer.headers.value(HttpHeaders.locationHeader), url);
    });
  });
}
