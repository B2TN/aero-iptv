import 'dart:io';

import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

void main() {
  late Directory directory;
  late AppDatabase db;
  late HttpServer server;
  late int sourceId;
  var status = HttpStatus.ok;

  setUp(() async {
    status = HttpStatus.ok;
    directory = await Directory.systemTemp.createTemp('iptv_import');
    db = AppDatabase(openAppDatabase(File('${directory.path}/test.db')));
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = status;
      request.response.write(
        File('test/fixtures/sample.m3u').readAsStringSync(),
      );
      await request.response.close();
    });
    final repository = PlaylistRepositoryImpl(db, MemoryCredentialStore());
    final added = await repository.add(
      name: 'Test',
      credentials: const M3uCredentials(playlistUrl: 'http://unused'),
    );
    sourceId = (added as Ok<PlaylistSource>).value.id;
  });

  tearDown(() async {
    await server.close(force: true);
    await db.close();
    await directory.delete(recursive: true);
  });

  PlaylistSource source() =>
      PlaylistSource(id: sourceId, name: 'Test', kind: SourceKind.m3u);

  M3uCredentials credentials() => M3uCredentials(
    playlistUrl: 'http://127.0.0.1:${server.port}/list.m3u',
    epgUrl: 'http://127.0.0.1:${server.port}/absent.xml',
  );

  test('importe dans un isolate et transmet la progression', () async {
    final events = await IsolateCatalogImporter(
      db,
    ).run(source(), credentials()).toList();

    expect(events.map((e) => e.stage), contains(ImportStage.catalog));
    expect(events.last.stage, ImportStage.done);
    expect(events.last.processed, 10);

    final countries = await LiveTvRepositoryImpl(db).countries(sourceId);
    expect(countries.map((c) => c.code), containsAll(['FR', 'GB']));
  });

  test('transmet une erreur typée depuis l isolate', () async {
    status = HttpStatus.forbidden;
    await expectLater(
      IsolateCatalogImporter(db).run(source(), credentials()).toList(),
      throwsA(isA<AuthFailure>()),
    );
    expect(await LiveTvRepositoryImpl(db).countries(sourceId), isEmpty);
  });
}
