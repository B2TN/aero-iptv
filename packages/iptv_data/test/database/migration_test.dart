import 'dart:io';

import 'package:drift/native.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('iptv_migration');
  });

  tearDown(() => directory.delete(recursive: true));

  test('la version 3 retire le cache des sous-titres téléchargés', () async {
    final file = File('${directory.path}/base.sqlite');
    // Base de la version 2 : même schéma, avec la table des sous-titres.
    final before = AppDatabase(NativeDatabase(file));
    await before.customSelect('SELECT 1').get();
    await before.customStatement(
      'CREATE TABLE subtitle_cache (content_key TEXT NOT NULL, '
      'language TEXT NOT NULL, content TEXT NOT NULL, '
      'PRIMARY KEY (content_key, language)) WITHOUT ROWID',
    );
    await before.customStatement(
      "INSERT INTO subtitle_cache VALUES ('x:m:1', 'fr', 'texte')",
    );
    await before.customStatement('PRAGMA user_version = 2');
    await before.close();

    final after = AppDatabase(NativeDatabase(file));
    final tables = await after
        .customSelect(
          "SELECT name FROM sqlite_master WHERE name = 'subtitle_cache'",
        )
        .get();
    final version = await after.customSelect('PRAGMA user_version').getSingle();
    await after.close();

    expect(tables, isEmpty);
    expect(version.read<int>('user_version'), 3);
  });
}
