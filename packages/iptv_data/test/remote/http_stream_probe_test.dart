import 'dart:io';

import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  final identities = <String?>[];
  final paths = <String>[];

  Future<StreamProbeResult?> probe(
    String path, {
    Map<String, String>? headers,
  }) => const HttpStreamProbe().probe(
    ResolvedStream(
      url: 'http://127.0.0.1:${server.port}$path',
      headers: headers ?? const {},
    ),
  );

  setUp(() async {
    identities.clear();
    paths.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = request.response;
      identities.add(request.headers.value(HttpHeaders.userAgentHeader));
      paths.add(request.uri.path);
      switch (request.uri.path) {
        case '/refus':
          response.statusCode = HttpStatus.unauthorized;
        case '/inconnu':
          response.statusCode = 884;
        case '/saut':
          response
            ..statusCode = HttpStatus.found
            ..headers.set(HttpHeaders.locationHeader, '/refus');
        case '/boucle':
          response
            ..statusCode = HttpStatus.found
            ..headers.set(HttpHeaders.locationHeader, '/boucle');
        case '/blocage':
          response.headers.contentType = ContentType.html;
          response.write('<html>page de blocage</html>');
        default:
          response.headers.contentType = ContentType('video', 'mp2t');
          response.write('flux');
      }
      await response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('donne le code d un refus', () async {
    final result = await probe('/refus');

    expect(result?.status, 401);
    expect(result?.redirectedTo, isNull);
  });

  test('garde un code inventé par le panneau', () async {
    expect((await probe('/inconnu'))?.status, 884);
  });

  test('envoie la même identité que le lecteur', () async {
    await probe('/refus');
    expect(identities.single, 'libmpv');

    await probe('/refus', headers: {'User-Agent': 'Lecteur/1'});
    expect(identities.last, 'Lecteur/1');
  });

  test('suit une redirection jusqu à la réponse finale', () async {
    final result = await probe('/saut');

    expect(result?.status, 401);
    expect(paths, ['/saut', '/refus']);
  });

  test('reconnaît une page web à la place de la vidéo', () async {
    expect((await probe('/blocage'))?.isVideo, isFalse);
    expect((await probe('/video'))?.isVideo, isTrue);
  });

  test('ne suit pas une boucle sans fin', () async {
    final result = await probe('/boucle');

    expect(result?.status, isNull);
    expect(paths.length, lessThanOrEqualTo(6));
  });

  test('signale un serveur muet', () async {
    final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close(force: true);

    final result = await const HttpStreamProbe().probe(
      ResolvedStream(url: 'http://127.0.0.1:$port/live/compte/secret/1.ts'),
    );

    expect(result, isNotNull);
    expect(result?.status, isNull);
  });

  test('laisse de côté un flux hors HTTP', () async {
    expect(
      await const HttpStreamProbe().probe(
        const ResolvedStream(url: 'rtmp://s.example/direct'),
      ),
      isNull,
    );
  });
}
