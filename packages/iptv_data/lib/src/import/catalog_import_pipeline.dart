import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/playlist_source_adapter.dart';
import '../database/app_database.dart';
import '../database/daos/catalog_maintenance_dao.dart';
import '../epg/epg_source_adapter.dart';
import 'catalog_session.dart';

/// Fenêtre de guide conservée autour de l'instant de synchronisation.
const Duration _epgHistory = Duration(hours: 2);
const Duration _epgHorizon = Duration(hours: 48);

/// Enchaîne téléchargement, normalisation, écriture et bascule du catalogue.
final class CatalogImportPipeline {
  CatalogImportPipeline({
    required AppDatabase database,
    required PlaylistSourceAdapter catalogAdapter,
    required EpgSourceAdapter epgAdapter,
    DateTime Function() clock = DateTime.now,
  }) : _db = database,
       _catalogAdapter = catalogAdapter,
       _epgAdapter = epgAdapter,
       _clock = clock,
       _maintenance = CatalogMaintenanceDao(database);

  final AppDatabase _db;
  final PlaylistSourceAdapter _catalogAdapter;
  final EpgSourceAdapter _epgAdapter;
  final DateTime Function() _clock;
  final CatalogMaintenanceDao _maintenance;

  /// Exécute la synchronisation de la source [sourceId].
  Stream<ImportProgress> run(
    int sourceId,
    PlaylistCredentials credentials,
  ) async* {
    yield const ImportProgress(ImportStage.connecting);
    await _maintenance.purgeOrphans();

    final catalogId = await _maintenance.create(sourceId, _clock());
    final session = CatalogSession(_db, catalogId);
    var processed = 0;
    String? discoveredEpgUrl;

    try {
      await for (final batch in _catalogAdapter.fetch(credentials)) {
        await session.write(batch);
        processed += batch.entries.length;
        discoveredEpgUrl ??= batch.discoveredEpgUrl;
        yield ImportProgress(ImportStage.catalog, processed: processed);
      }
      if (processed == 0) {
        throw const ParseFailure('La source ne contient aucune entrée.');
      }
      yield ImportProgress(ImportStage.indexing, processed: processed);
      await _maintenance.separateHomonyms(catalogId);
      await _maintenance.mergeTranslatedVersions(catalogId);
      await _maintenance.buildSearchIndex(catalogId);
    } catch (_) {
      await _maintenance.purge(catalogId);
      rethrow;
    }

    final previous = await _maintenance.activate(sourceId, catalogId, _clock());
    if (previous != null) await _maintenance.purge(previous);

    final epgFailed = !await _importEpg(
      sourceId,
      catalogId,
      credentials,
      discoveredEpgUrl,
    ).catchError((Object error) => error is Failure ? false : throw error);
    yield ImportProgress(
      ImportStage.done,
      processed: processed,
      epgFailed: epgFailed,
    );
  }

  /// Le guide est facultatif : son échec n'annule pas le catalogue déjà activé.
  Future<bool> _importEpg(
    int sourceId,
    int catalogId,
    PlaylistCredentials credentials,
    String? discoveredUrl,
  ) async {
    final now = _clock().toUtc();
    final keys = await _db.epgKeysOfCatalog(catalogId: catalogId).get();
    final request = EpgRequest(
      credentials: credentials,
      knownKeys: keys.whereType<String>().toSet(),
      from: now.subtract(_epgHistory),
      to: now.add(_epgHorizon),
      discoveredUrl: discoveredUrl,
    );

    await for (final programmes in _epgAdapter.fetch(request)) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.epgProgrammes, [
          for (final programme in programmes)
            EpgProgrammesCompanion.insert(
              sourceId: sourceId,
              epgKey: programme.epgKey,
              startAt: _seconds(programme.start),
              stopAt: _seconds(programme.stop),
              title: programme.title,
              description: Value(programme.description),
            ),
        ]);
      });
    }
    await _db.deleteExpiredProgrammes(
      sourceId: sourceId,
      before: _seconds(request.from),
    );
    return true;
  }

  int _seconds(DateTime instant) =>
      instant.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
}
