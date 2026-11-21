import 'dart:async';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/adapter_resolver.dart';
import '../database/app_database.dart';
import 'catalog_import_pipeline.dart';
import 'import_failure.dart';

/// Lance l'import dans un isolate, pour que le parsing ne touche jamais au
/// thread de l'interface.
///
/// La base doit avoir été ouverte avec `openAppDatabase`.
final class IsolateCatalogImporter implements CatalogImporter {
  const IsolateCatalogImporter(this._database);

  final AppDatabase _database;

  @override
  Stream<ImportProgress> run(
    PlaylistSource source,
    PlaylistCredentials credentials, {
    bool full = false,
    ImportPause? pause,
  }) {
    final port = ReceivePort();
    final controller = StreamController<ImportProgress>();
    StreamSubscription<bool>? pauses;

    final subscription = port.listen((message) {
      if (message is SendPort) {
        // L'isolate envoie d'abord son port de commande : il y reçoit l'état
        // de la pause, puis chacun de ses changements.
        message.send(pause?.isPaused ?? false);
        pauses = pause?.changes.listen(message.send);
        return;
      }
      controller.add(message as ImportProgress);
    });

    unawaited(
      _spawn(_database, port.sendPort, source.id, credentials, full)
          .catchError(
            (Object error, StackTrace stack) =>
                controller.addError(importFailureOf(error), stack),
          )
          .whenComplete(() async {
            // Les derniers messages de l'isolate précèdent sa fin : le port
            // les a déjà reçus lorsque ce rappel s'exécute.
            await Future<void>.delayed(Duration.zero);
            await subscription.cancel();
            await pauses?.cancel();
            port.close();
            await controller.close();
          }),
    );
    return controller.stream;
  }

  /// Méthode statique : la fermeture envoyée à l'isolate ne doit capturer que
  /// des valeurs transférables, et donc ni le port ni le contrôleur de flux.
  static Future<void> _spawn(
    AppDatabase database,
    SendPort progress,
    int sourceId,
    PlaylistCredentials credentials,
    bool full,
  ) => database.computeWithDatabase<void, AppDatabase>(
    computation: (isolateDatabase) =>
        _runImport(isolateDatabase, progress, sourceId, credentials, full),
    connect: AppDatabase.new,
  );

  static Future<void> _runImport(
    AppDatabase database,
    SendPort progress,
    int sourceId,
    PlaylistCredentials credentials,
    bool full,
  ) async {
    final client = http.Client();
    final pause = ImportPause();
    final commands = ReceivePort();
    commands.listen((paused) => pause.set(paused: paused as bool));
    progress.send(commands.sendPort);
    try {
      final adapters = AdapterResolver(client);
      final pipeline = CatalogImportPipeline(
        database: database,
        catalogAdapter: adapters.catalogFor(credentials),
        epgAdapter: adapters.epgFor(credentials),
      );
      await pipeline
          .run(sourceId, credentials, full: full, pause: pause)
          .forEach(progress.send);
    } on Object catch (error, stack) {
      // Converti ici, où l'erreur est encore intacte : toutes ne survivent pas
      // au passage entre isolates.
      Error.throwWithStackTrace(importFailureOf(error), stack);
    } finally {
      commands.close();
      client.close();
    }
  }
}
