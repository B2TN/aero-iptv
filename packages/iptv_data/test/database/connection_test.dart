import 'dart:io';

import 'package:drift/drift.dart' show Variable;

import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_data/src/database/daos/catalog_maintenance_dao.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// Lignes d'une série renommée d'un coup par le regroupement des versions.
const int _renamedRows = 300;

/// Remplit le catalogue 1 de deux clés d'une même série TMDb, dispersées dans
/// toute la table : renommer la plus petite touche des centaines de pages, ce
/// qui oblige SQLite à écrire un fichier temporaire.
Future<void> _fillWithSplitSeries(AppDatabase db) async {
  await db.customStatement(
    "INSERT INTO sources (name, kind, active_catalog_id) VALUES ('s', 1, NULL)",
  );
  await db.customStatement(
    'INSERT INTO catalogs (source_id, created_at) VALUES (1, 0)',
  );
  Future<void> insert(String key, String? tmdb, String title) =>
      db.customStatement(
        'INSERT INTO series_entries (catalog_id, raw_title, display_title, '
        'title_key, grouping_key, year, language_tag, category, poster_url, '
        'xtream_series_id, tmdb_id, sort_order) VALUES '
        "(1, ?1, ?1, ?2, ?2, 2020, 'FR', 'Séries', NULL, 1, ?3, 1)",
        [title, key, tmdb],
      );
  await db.transaction(() async {
    for (var row = 0; row < _renamedRows * 10; row++) {
      final title = '${'Titre long ' * 30}$row';
      await switch (row % 10) {
        0 => insert('serie', '42', title),
        1 => insert('seriebis', '42', title),
        _ => insert('autre$row', null, title),
      };
    }
    // Une version de plus : c'est l'autre clé qui sera renommée.
    await insert('seriebis', '42', 'Série bis');
  });
}

Future<int> _keysOf(AppDatabase db, String tmdb) async {
  final row = await db
      .customSelect(
        'SELECT COUNT(DISTINCT grouping_key) AS n FROM series_entries '
        'WHERE tmdb_id = ?1',
        variables: [Variable.withString(tmdb)],
      )
      .getSingle();
  return row.read<int>('n');
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('iptv_connection');
  });

  tearDown(() async {
    // Le réglage vaut pour tout le processus : il ne doit pas survivre au
    // dossier qu'il désigne.
    sqlite3.tempDirectory = null;
    await directory.delete(recursive: true);
  });

  test('donne à SQLite le dossier temporaire fourni', () async {
    final temporary = await Directory('${directory.path}/tmp').create();
    final db = AppDatabase(
      openAppDatabase(
        File('${directory.path}/a.db'),
        temporaryDirectory: temporary,
      ),
    );
    await db.customSelect('SELECT 1').get();
    await db.close();

    expect(sqlite3.tempDirectory, temporary.path);
  });

  test('regroupe une grosse série avec un dossier temporaire', () async {
    final temporary = await Directory('${directory.path}/tmp').create();
    final db = AppDatabase(
      openAppDatabase(
        File('${directory.path}/b.db'),
        temporaryDirectory: temporary,
      ),
    );
    await _fillWithSplitSeries(db);

    await CatalogMaintenanceDao(db).mergeTranslatedVersions(1);

    expect(await _keysOf(db, '42'), 1);
    await db.close();
  });

  // Ce que la box Android subissait : sans dossier temporaire utilisable, le
  // regroupement échoue, et l'erreur doit dire pourquoi.
  test('sans dossier temporaire, l erreur garde sa vraie cause', () async {
    final db = AppDatabase(openAppDatabase(File('${directory.path}/c.db')));
    await _fillWithSplitSeries(db);
    await db.customSelect('SELECT 1').get();
    sqlite3.tempDirectory = '${directory.path}/absent';

    await expectLater(
      CatalogMaintenanceDao(db).mergeTranslatedVersions(1),
      // L'erreur arrive de l'isolate de la base, enveloppée par Drift.
      throwsA(
        predicate<Object>(
          (error) =>
              '$error'.contains('SqliteException') &&
              !'$error'.contains('cannot rollback'),
          'une erreur SQLite autre que l annulation impossible',
        ),
      ),
    );
    expect(await _keysOf(db, '42'), 2);
    sqlite3.tempDirectory = null;
    await db.close();
  });

  test('une transaction annulée par SQLite garde l erreur d origine', () async {
    final db = AppDatabase(openAppDatabase(File('${directory.path}/d.db')));
    await db.customSelect('SELECT 1').get();

    await expectLater(
      transactionKeepingCause(db, () async {
        // SQLite annule de lui-même, comme après une erreur d'écriture.
        await db.customStatement('ROLLBACK');
        throw StateError('cause');
      }),
      throwsA(isA<StateError>()),
    );
    // La base reste utilisable.
    expect(await db.customSelect('SELECT 1 AS n').getSingle(), isNotNull);
    await db.close();
  });
}
