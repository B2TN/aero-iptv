import 'dart:io';

import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/playlist_source_adapter.dart';
import '../database/app_database.dart';
import '../database/daos/catalog_maintenance_dao.dart';
import '../epg/epg_source_adapter.dart';
import 'catalog_session.dart';
import 'import_failure.dart';

/// Fenêtre de guide conservée autour de l'instant de synchronisation.
const Duration _epgHistory = Duration(hours: 2);
const Duration _epgHorizon = Duration(hours: 48);

/// Essais par section. Un panneau surchargé coupe une réponse ou renvoie une
/// page d'erreur, puis répond normalement quelques secondes plus tard.
const int _sectionAttempts = 3;

/// Attente avant le deuxième essai, doublée avant le troisième.
const Duration _retryDelay = Duration(seconds: 4);

Future<void> _wait(Duration duration) => Future<void>.delayed(duration);

/// Enchaîne téléchargement, normalisation, écriture et bascule du catalogue.
final class CatalogImportPipeline {
  CatalogImportPipeline({
    required AppDatabase database,
    required PlaylistSourceAdapter catalogAdapter,
    required EpgSourceAdapter epgAdapter,
    DateTime Function() clock = DateTime.now,
    Future<void> Function(Duration duration) pause = _wait,
  }) : _db = database,
       _catalogAdapter = catalogAdapter,
       _epgAdapter = epgAdapter,
       _clock = clock,
       _pause = pause,
       _maintenance = CatalogMaintenanceDao(database);

  final AppDatabase _db;
  final PlaylistSourceAdapter _catalogAdapter;
  final EpgSourceAdapter _epgAdapter;
  final DateTime Function() _clock;
  final Future<void> Function(Duration duration) _pause;
  final CatalogMaintenanceDao _maintenance;

  /// Exécute la synchronisation de la source [sourceId].
  ///
  /// Chaque section est téléchargée à part, et reprise en cas de panne
  /// passagère. Si l'une d'elles reste en échec, les autres sont tout de même
  /// activées : elle garde alors son contenu précédent, et le dernier
  /// avancement la signale.
  Stream<ImportProgress> run(
    int sourceId,
    PlaylistCredentials credentials,
  ) async* {
    yield const ImportProgress(ImportStage.connecting);
    await _maintenance.purgeOrphans();
    // Un accès refusé s'arrête ici, avant d'avoir réservé quoi que ce soit.
    final sections = await _catalogAdapter.open(credentials);

    final catalogId = await _maintenance.create(sourceId, _clock());
    final session = CatalogSession(_db, catalogId);
    final failed = <ContentKind, Failure>{};
    var processed = 0;
    String? discoveredEpgUrl;

    try {
      for (final section in sections) {
        final kind = section.kind;
        for (var attempt = 1; ; attempt++) {
          var received = 0;
          try {
            await for (final batch in section.fetch()) {
              await session.write(batch);
              received += batch.entries.length;
              discoveredEpgUrl ??= batch.discoveredEpgUrl;
              yield ImportProgress(
                ImportStage.catalog,
                section: kind,
                processed: processed + received,
              );
            }
            processed += received;
            break;
          } on Object catch (error, stack) {
            // Même imprévue, l'erreur d'une section ne coûte pas les autres.
            final failure = importFailureOf(error);
            // Ce que l'essai a écrit est incomplet : le suivant repart de zéro.
            await _maintenance.purgeSection(catalogId, kind);
            session.forget(kind);
            if (attempt < _sectionAttempts && _isTransient(failure)) {
              await _pause(_retryDelay * attempt);
              continue;
            }
            // Une source d'un seul tenant n'a rien d'autre à sauver.
            if (kind == null) Error.throwWithStackTrace(failure, stack);
            failed[kind] = failure;
            break;
          }
        }
      }
      if (processed == 0) {
        throw failed.values.firstOrNull ??
            const ParseFailure('La source ne contient aucune entrée.');
      }
      final shown = await _maintenance.activeCatalogOf(sourceId);
      if (shown != null) {
        for (final kind in failed.keys) {
          await _maintenance.carryOver(shown, catalogId, kind);
        }
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

    // Le catalogue est déjà consultable : le guide se télécharge ensuite.
    yield ImportProgress(
      ImportStage.epg,
      processed: processed,
      failedSections: failed,
    );
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
      failedSections: failed,
    );
  }

  /// Une panne passagère mérite un nouvel essai, pas un refus du compte.
  bool _isTransient(Failure failure) => switch (failure) {
    NetworkFailure() ||
    SecureConnectionFailure() ||
    ParseFailure() ||
    RateLimitFailure() => true,
    ServerFailure(:final status) => status >= HttpStatus.internalServerError,
    _ => false,
  };

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
