import 'dart:io';

import 'package:drift/native.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:test/test.dart';

/// Colonnes apparues en version 4 : résumés, genres et durées.
const Map<String, List<String>> _detailColumns = {
  'movies': ['overview', 'genre', 'runtime_minutes', 'details_loaded'],
  'series_entries': ['overview', 'genre', 'runtime_minutes', 'details_loaded'],
  'episodes': ['overview'],
};

/// Ramène une base neuve au schéma de la version 3, sans les colonnes de la
/// version 4, puis la marque de [version].
Future<void> _downgrade(AppDatabase database, int version) async {
  for (final MapEntry(key: table, value: columns) in _detailColumns.entries) {
    for (final column in columns) {
      await database.customStatement('ALTER TABLE $table DROP COLUMN $column');
    }
  }
  await database.customStatement('PRAGMA user_version = $version');
}

Future<List<String>> _columnsOf(AppDatabase database, String table) async => [
  for (final row
      in await database.customSelect('PRAGMA table_info($table)').get())
    row.read<String>('name'),
];

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('iptv_migration');
    file = File('${directory.path}/base.sqlite');
  });

  tearDown(() => directory.delete(recursive: true));

  test('la version 3 retire le cache des sous-titres téléchargés', () async {
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
    await _downgrade(before, 2);
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
    expect(version.read<int>('user_version'), after.schemaVersion);
  });

  test('la version 4 ajoute les résumés sans toucher au catalogue', () async {
    final before = AppDatabase(NativeDatabase(file));
    await before.customSelect('SELECT 1').get();
    await _downgrade(before, 3);
    await before.customStatement(
      "INSERT INTO movies (catalog_id, raw_title, display_title, title_key, "
      "content_key, sort_order) VALUES (1, 'Dune', 'Dune', 'dune', 'x:m:1', 0)",
    );
    await before.close();

    final after = AppDatabase(NativeDatabase(file));
    for (final MapEntry(key: table, value: columns) in _detailColumns.entries) {
      expect(
        await _columnsOf(after, table),
        containsAll(columns),
        reason: table,
      );
    }
    final movie = await after
        .customSelect('SELECT display_title, details_loaded FROM movies')
        .getSingle();
    await after.close();

    expect(movie.read<String>('display_title'), 'Dune');
    // Les résumés restent à demander au fournisseur.
    expect(movie.read<bool>('details_loaded'), isFalse);
  });
}
