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

/// Colonnes apparues en version 6 : identité commune aux versions, vu, retiré.
const List<String> _progressColumns = [
  'work_key',
  'series_key',
  'season',
  'episode',
  'finished',
  'hidden',
];

/// Ramène une base neuve au schéma de [version] : sans les favoris avant la
/// version 5, sans les colonnes de résumés avant la version 4.
Future<void> _downgrade(AppDatabase database, int version) async {
  if (version < 8) {
    await database.customStatement(
      'ALTER TABLE live_channels DROP COLUMN national_rank',
    );
  }
  if (version < 7) {
    for (final index in [
      'movies_content',
      'series_entry_key',
      'episodes_content',
    ]) {
      await database.customStatement('DROP INDEX $index');
    }
    for (final column in ['entry_key', 'last_modified']) {
      await database.customStatement(
        'ALTER TABLE series_entries DROP COLUMN $column',
      );
    }
  }
  if (version < 6) {
    for (final column in _progressColumns) {
      await database.customStatement(
        'ALTER TABLE watch_progress DROP COLUMN $column',
      );
    }
  }
  if (version < 5) await database.customStatement('DROP TABLE favorites');
  if (version < 4) {
    for (final MapEntry(key: table, value: columns) in _detailColumns.entries) {
      for (final column in columns) {
        await database.customStatement(
          'ALTER TABLE $table DROP COLUMN $column',
        );
      }
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

  test('la version 5 ajoute les favoris', () async {
    final before = AppDatabase(NativeDatabase(file));
    await before.customSelect('SELECT 1').get();
    await _downgrade(before, 4);
    await before.close();

    final after = AppDatabase(NativeDatabase(file));
    final columns = await _columnsOf(after, 'favorites');
    await after.close();

    expect(columns, containsAll(['source_id', 'kind', 'favorite_key']));
  });

  test('la version 6 relie les reprises à leur contenu', () async {
    final before = AppDatabase(NativeDatabase(file));
    await before.customSelect('SELECT 1').get();
    await _downgrade(before, 5);
    for (final statement in [
      "INSERT INTO sources (id, name, kind, active_catalog_id) "
          "VALUES (1, 'Essai', 1, 1)",
      'INSERT INTO catalogs (id, source_id, created_at) VALUES (1, 1, 0)',
      "INSERT INTO series_entries (id, catalog_id, raw_title, display_title, "
          "title_key, grouping_key, sort_order) "
          "VALUES (7, 1, 'FR - Abysses', 'Abysses', 'abysses', 'abysses', 0)",
      "INSERT INTO episodes (catalog_id, series_entry_id, season, number, "
          "title, content_key) VALUES (1, 7, 2, 3, 'Abysses', 'x:e:23')",
      "INSERT INTO movies (catalog_id, raw_title, display_title, title_key, "
          "content_key, sort_order) "
          "VALUES (1, 'FR - Dune', 'Dune', 'dune', 'x:m:1', 0)",
      for (final (key, kind) in [
        ('x:e:23', 2),
        ('x:m:1', 1),
        ('x:m:disparu', 1),
      ])
        "INSERT INTO watch_progress (source_id, content_key, kind, title, "
            "position_ms, duration_ms, updated_at) "
            "VALUES (1, '$key', $kind, 'Reprise', 1000, 2000, 0)",
    ]) {
      await before.customStatement(statement);
    }
    await before.close();

    final after = AppDatabase(NativeDatabase(file));
    final rows = await after
        .customSelect(
          'SELECT content_key, work_key, series_key, season, episode, '
          'finished, hidden FROM watch_progress ORDER BY content_key',
        )
        .get();
    await after.close();

    final byKey = {
      for (final row in rows) row.read<String>('content_key'): row,
    };
    final episode = byKey['x:e:23']!;
    expect(episode.read<String?>('work_key'), 'e:abysses:2:3');
    expect(episode.read<String?>('series_key'), 'abysses');
    expect(episode.read<int?>('season'), 2);
    expect(episode.read<int?>('episode'), 3);
    expect(byKey['x:m:1']!.read<String?>('work_key'), 'm:dune');
    // Hors du catalogue : la reprise reste, sans identité commune.
    expect(byKey['x:m:disparu']!.read<String?>('work_key'), isNull);
    expect(episode.read<bool>('finished'), isFalse);
    expect(episode.read<bool>('hidden'), isFalse);
  });

  test('la version 7 prépare la synchronisation différentielle', () async {
    final before = AppDatabase(NativeDatabase(file));
    await before.customSelect('SELECT 1').get();
    await _downgrade(before, 6);
    await before.customStatement(
      "INSERT INTO series_entries (catalog_id, raw_title, display_title, "
      "title_key, grouping_key, sort_order) "
      "VALUES (1, 'Abysses', 'Abysses', 'abysses', 'abysses', 0)",
    );
    await before.customStatement(
      "INSERT INTO search_index (title, group_key, kind, ref_id, catalog_id) "
      "VALUES ('Abysses', 'sabysses', 2, 1, 1)",
    );
    await before.close();

    final after = AppDatabase(NativeDatabase(file));
    final columns = await _columnsOf(after, 'series_entries');
    final series = await after
        .customSelect('SELECT entry_key, last_modified FROM series_entries')
        .getSingle();
    final indexes = await after
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name IN ('movies_content', 'series_entry_key', "
          "'episodes_content')",
        )
        .get();
    final searchRows = await after
        .customSelect('SELECT COUNT(*) AS n FROM search_index')
        .getSingle();
    await after.close();

    expect(columns, containsAll(['entry_key', 'last_modified']));
    // Vide jusqu'au réimport, qui la remplit.
    expect(series.read<String>('entry_key'), '');
    expect(series.readNullable<int>('last_modified'), isNull);
    expect(indexes, hasLength(3));
    // L'index de recherche se reconstruit au réimport.
    expect(searchRows.read<int>('n'), 0);
  });
}
