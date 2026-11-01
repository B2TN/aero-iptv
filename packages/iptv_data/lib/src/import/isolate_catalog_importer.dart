import 'dart:async';
import 'dart:isolate';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/adapter_resolver.dart';
import '../database/app_database.dart';
import 'catalog_import_pipeline.dart';

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
    PlaylistCredentials credentials,
  ) {
    final port = ReceivePort();
    final controller = StreamController<ImportProgress>();

    final subscription = port.cast<ImportProgress>().listen(controller.add);

    unawaited(
      _spawn(
        _database,
        port.sendPort,
        source.id,
        credentials,
      ).catchError(controller.addError).whenComplete(() async {
        // Les derniers messages de l'isolate précèdent sa fin : le port
        // les a déjà reçus lorsque ce rappel s'exécute.
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();
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
  ) => database.computeWithDatabase<void, AppDatabase>(
    computation: (isolateDatabase) =>
        _runImport(isolateDatabase, progress, sourceId, credentials),
    connect: AppDatabase.new,
  );

  static Future<void> _runImport(
    AppDatabase database,
    SendPort progress,
    int sourceId,
    PlaylistCredentials credentials,
  ) async {
    final client = http.Client();
    try {
      final adapters = AdapterResolver(client);
      final pipeline = CatalogImportPipeline(
        database: database,
        catalogAdapter: adapters.catalogFor(credentials),
        epgAdapter: adapters.epgFor(credentials),
      );
      await pipeline.run(sourceId, credentials).forEach(progress.send);
    } finally {
      client.close();
    }
  }
}
