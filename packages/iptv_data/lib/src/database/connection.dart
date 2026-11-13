import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

/// Ouvre la base dans un isolate dédié, pour ne jamais bloquer l'interface.
///
/// [temporaryDirectory] reçoit les fichiers temporaires de SQLite, et doit
/// exister. Il est indispensable sur Android : SQLite y cherche un dossier
/// temporaire commun que l'application n'a pas toujours le droit d'utiliser.
/// Une grosse modification, comme le regroupement des versions d'un catalogue,
/// échouait alors au moment de déborder de la mémoire.
QueryExecutor openAppDatabase(File file, {Directory? temporaryDirectory}) {
  // Seul le chemin part vers l'isolate de la base.
  final temporaryPath = temporaryDirectory?.path;
  return NativeDatabase.createInBackground(
    file,
    setup: (database) {
      // Réglage commun à tout le processus, à faire avant la première requête.
      if (temporaryPath != null) sqlite3.tempDirectory = temporaryPath;
      configureConnection(database);
    },
  );
}

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

/// Exécute [action] dans une transaction, sans perdre la cause d'un échec.
///
/// Après certaines erreurs, comme un fichier temporaire impossible à créer,
/// SQLite annule lui-même la transaction. L'annulation que Drift tente ensuite
/// échoue à son tour, et son message « cannot rollback » remplacerait celui de
/// l'erreur d'origine.
Future<T> transactionKeepingCause<T>(
  GeneratedDatabase database,
  Future<T> Function() action,
) async {
  Object? cause;
  StackTrace? causeStack;
  try {
    return await database.transaction(() async {
      try {
        return await action();
      } catch (error, stack) {
        cause = error;
        causeStack = stack;
        rethrow;
      }
    });
  } catch (error) {
    final original = cause;
    if (original != null && !identical(original, error)) {
      Error.throwWithStackTrace(original, causeStack!);
    }
    rethrow;
  }
}
