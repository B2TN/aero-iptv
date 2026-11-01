import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

/// Ouvre la base dans un isolate dédié, pour ne jamais bloquer l'interface.
QueryExecutor openAppDatabase(File file) =>
    NativeDatabase.createInBackground(file, setup: configureConnection);

/// Réglages de connexion adaptés aux appareils limités en mémoire.
void configureConnection(Database database) {
  database
    // Un écrivain ne bloque pas les lecteurs.
    ..execute('PRAGMA journal_mode = WAL')
    ..execute('PRAGMA synchronous = NORMAL')
    ..execute('PRAGMA foreign_keys = ON')
    // Cache de pages plafonné à 4 Mio, fichiers temporaires hors de la RAM.
    ..execute('PRAGMA cache_size = -4096')
    ..execute('PRAGMA temp_store = FILE')
    ..execute('PRAGMA mmap_size = 0');
}
