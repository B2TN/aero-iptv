import 'dart:convert';
import 'dart:io';

import 'package:aero_iptv/app/platform/api_key_store.dart';
import 'package:aero_iptv/app/platform/platform_credential_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

void main() {
  group('coffre Windows', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('iptv_vault');
    });

    tearDown(() => directory.delete(recursive: true));

    test('retrouve les identifiants', () async {
      final store = WindowsCredentialStore(directory);
      await store.write(
        1,
        const XtreamCredentials(
          serverUrl: 'http://s.example',
          username: 'jean',
          password: 'mot-de-passe-é',
        ),
      );

      final read = await store.read(1);

      expect(read, isA<XtreamCredentials>());
      expect((read! as XtreamCredentials).password, 'mot-de-passe-é');
    });

    test('conserve une clé d API chiffrée, puis l efface', () async {
      final store = createApiKeyStore(directory);
      expect(await store.read('deepl'), isNull);

      await store.write('deepl', 'cle-secrete:fx');

      expect(await store.read('deepl'), 'cle-secrete:fx');
      final file = directory.listSync().whereType<File>().single;
      expect(latin1.decode(file.readAsBytesSync()), isNot(contains('secrete')));

      await store.write('deepl', null);

      expect(await store.read('deepl'), isNull);
      expect(directory.listSync(), isEmpty);
    });

    test('ne laisse rien en clair sur le disque', () async {
      await WindowsCredentialStore(directory).write(
        1,
        const M3uCredentials(playlistUrl: 'http://s.example/secret.m3u'),
      );

      final file = directory.listSync().whereType<File>().single;
      final content = latin1.decode(file.readAsBytesSync());

      expect(content, isNot(contains('secret')));
    });

    test('supprime les identifiants', () async {
      final store = WindowsCredentialStore(directory);
      await store.write(
        1,
        const M3uCredentials(playlistUrl: 'http://s.example/a.m3u'),
      );
      await store.delete(1);

      expect(await store.read(1), isNull);
    });

    test('retourne null pour une source inconnue', () async {
      expect(await WindowsCredentialStore(directory).read(9), isNull);
    });
  }, skip: Platform.isWindows ? false : 'DPAPI n existe que sous Windows');
}
