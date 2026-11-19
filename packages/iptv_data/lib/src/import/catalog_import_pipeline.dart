import 'dart:io';

import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/catalog_batch.dart';
import '../adapters/playlist_source_adapter.dart';
import '../database/app_database.dart';
import '../database/daos/catalog_maintenance_dao.dart';
import '../database/daos/catalog_merge_dao.dart';
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
       _maintenance = CatalogMaintenanceDao(database),
       _merge = CatalogMergeDao(database);

  final AppDatabase _db;
  final PlaylistSourceAdapter _catalogAdapter;
  final EpgSourceAdapter _epgAdapter;
  final DateTime Function() _clock;
  final Future<void> Function(Duration duration) _pause;
  final CatalogMaintenanceDao _maintenance;
  final CatalogMergeDao _merge;

  /// Exécute la synchronisation de la source [sourceId].
  ///
  /// Chaque section est téléchargée à part, et reprise en cas de panne
  /// passagère. Si l'une d'elles reste en échec, les autres sont tout de même
  /// appliquées : elle garde alors son contenu précédent, et le dernier
  /// avancement la signale.
  ///
  /// Quand un catalogue est déjà affiché, seules ses différences avec celui
  /// qui vient d'arriver lui sont appliquées. [full] le remplace en entier,
  /// comme au premier import : les règles de nettoyage ont changé, et tous
  /// les titres avec elles.
  Stream<ImportProgress> run(
    int sourceId,
    PlaylistCredentials credentials, {
    bool full = false,
  }) async* {
    yield const ImportProgress(ImportStage.connecting);
    await _maintenance.purgeOrphans();
    // Un accès refusé s'arrête ici, avant d'avoir réservé quoi que ce soit.
    final sections = await _catalogAdapter.open(credentials);

    final shown = await _maintenance.activeCatalogOf(sourceId);
    final merging = !full && shown != null && await _merge.canMergeInto(shown);
    // Quand chaque section reconnaît ses entrées avant de les décoder
    // (Xtream), seules celles qui ont changé sont traitées.
    final gates =
        merging &&
            sections.every(
              (section) => section.kind != null && section.fetchChanges != null,
            )
        ? await _SyncGates.load(_merge, sourceId, shown)
        : null;
    final catalogId = await _maintenance.create(sourceId, _clock());
    final session = CatalogSession(_db, catalogId);
    final failed = <ContentKind, Failure>{};
    var processed = 0;
    String? discoveredEpgUrl;

    /// Télécharge [section] par [fetch], en la reprenant après une panne
    /// passagère. Une section restée en échec rejoint [failed].
    Stream<ImportProgress> download(
      SourceSection section,
      Stream<CatalogBatch> Function() fetch,
    ) async* {
      final kind = section.kind;
      for (var attempt = 1; ; attempt++) {
        var received = 0;
        try {
          await for (final batch in fetch()) {
            await session.write(batch);
            received += batch.received;
            discoveredEpgUrl ??= batch.discoveredEpgUrl;
            yield ImportProgress(
              ImportStage.catalog,
              section: kind,
              processed: processed + received,
              merged: merging,
            );
          }
          processed += received;
          return;
        } on Object catch (error, stack) {
          // Même imprévue, l'erreur d'une section ne coûte pas les autres.
          final failure = importFailureOf(error);
          // Ce que l'essai a écrit est incomplet : le suivant repart de zéro.
          await _maintenance.purgeSection(catalogId, kind);
          session.forget(kind);
          gates?.forget(kind);
          if (attempt < _sectionAttempts && _isTransient(failure)) {
            await _pause(_retryDelay * attempt);
            continue;
          }
          // Une source d'un seul tenant n'a rien d'autre à sauver.
          if (kind == null) Error.throwWithStackTrace(failure, stack);
          failed[kind] = failure;
          return;
        }
      }
    }

    try {
      for (final section in sections) {
        final kind = section.kind;
        final gate = kind == null ? null : gates?.gateFor(kind);
        // Pas de `yield*` : il transmettrait les erreurs de la section sans
        // passer par le `catch` ci-dessous, qui efface le catalogue en cours.
        if (gate == null) {
          await for (final progress in download(section, section.fetch)) {
            yield progress;
          }
          continue;
        }
        final before = processed;
        await for (final progress in download(
          section,
          () => section.fetchChanges!(gate),
        )) {
          yield progress;
        }
        // Les chaînes se comparent d'un bloc : si leur liste a changé, elle
        // est téléchargée à nouveau, entière.
        if (kind == ContentKind.live && !failed.containsKey(kind)) {
          gates!.finishLive();
          if (gates.liveChanged) {
            processed = before;
            await for (final progress in download(section, section.fetch)) {
              yield progress;
            }
          }
        }
      }
      if (processed == 0) {
        throw failed.values.firstOrNull ??
            const ParseFailure('La source ne contient aucune entrée.');
      }
      if (!merging && shown != null) {
        for (final kind in failed.keys) {
          await _maintenance.carryOver(shown, catalogId, kind);
        }
      }
      yield ImportProgress(
        ImportStage.indexing,
        processed: processed,
        merged: merging,
      );
    } catch (_) {
      await _discard(catalogId);
      rethrow;
    }

    // Les finitions améliorent le catalogue, mais aucune ne doit empêcher de
    // l'afficher : celle qui échoue est signalée, et l'import continue. La
    // synchronisation tient l'index de recherche à jour titre par titre ; en
    // ne traitant que les changements, elle regroupe aussi les versions des
    // films et des séries dans le catalogue affiché.
    final refinements = <CatalogRefinement, Future<void> Function()>{
      if (gates == null) ...{
        CatalogRefinement.homonyms: () =>
            _maintenance.separateHomonyms(catalogId),
        CatalogRefinement.versions: () =>
            _maintenance.mergeTranslatedVersions(catalogId),
      },
      if (!merging)
        CatalogRefinement.search: () =>
            _maintenance.buildSearchIndex(catalogId),
    };
    final failedRefinements = <CatalogRefinement, Failure>{};
    for (final MapEntry(key: step, value: refine) in refinements.entries) {
      try {
        await refine();
      } on Object catch (error) {
        failedRefinements[step] = importFailureOf(error);
      }
    }

    final int shownNow;
    if (merging) {
      try {
        if (gates != null) {
          await _mergeChanges(sourceId, catalogId, shown, gates, failed);
        } else {
          // Une source d'un seul tenant (M3U) n'a qu'une section, sans genre.
          for (final kind in {for (final section in sections) section.kind}) {
            if (failed.containsKey(kind)) continue;
            await _merge.merge(catalogId, shown, kind);
          }
        }
        await _maintenance.markSynced(sourceId, _clock());
      } finally {
        await _discard(catalogId);
      }
      shownNow = shown;
    } else {
      if (shown != null) {
        try {
          await _maintenance.carryLoaded(shown, catalogId);
        } on Object {
          // Ce qui a été chargé se redemande à l'ouverture : son oubli ne
          // doit pas empêcher d'afficher le catalogue.
        }
      }
      final int? previous;
      try {
        previous = await _maintenance.activate(sourceId, catalogId, _clock());
      } catch (_) {
        await _discard(catalogId);
        rethrow;
      }
      if (previous != null) await _discard(previous);
      shownNow = catalogId;
    }
    try {
      await _db.refreshUserKeys();
    } on Object {
      // Un favori ou une reprise qui n'a pas suivi sa fiche s'y rattachera à
      // la prochaine synchronisation : le catalogue reste à afficher.
    }

    // Le catalogue est déjà consultable : le guide se télécharge ensuite.
    yield ImportProgress(
      ImportStage.epg,
      processed: processed,
      failedSections: failed,
      failedRefinements: failedRefinements,
      merged: merging,
    );
    final epgFailed = !await _importEpg(
      sourceId,
      shownNow,
      credentials,
      discoveredEpgUrl,
    ).catchError((Object error) => error is Failure ? false : throw error);
    yield ImportProgress(
      ImportStage.done,
      processed: processed,
      epgFailed: epgFailed,
      failedSections: failed,
      failedRefinements: failedRefinements,
      merged: merging,
    );
  }

  /// Applique à [shown] les seuls changements que [gates] ont laissé passer
  /// dans [fresh], et retire ce qu'elles n'ont plus vu.
  Future<void> _mergeChanges(
    int sourceId,
    int fresh,
    int shown,
    _SyncGates gates,
    Map<ContentKind, Failure> failed,
  ) async {
    if (!failed.containsKey(ContentKind.live)) {
      if (gates.liveChanged) await _merge.replaceLive(fresh, shown);
      await _merge.saveLiveHash(sourceId, gates.liveHash);
    }
    if (!failed.containsKey(ContentKind.movie)) {
      await _merge.mergeMovies(
        fresh,
        shown,
        removed: gates.removed(ContentKind.movie),
      );
      await _merge.backfillMovieHashes(shown, gates.unhashedMovies);
    }
    if (!failed.containsKey(ContentKind.series)) {
      await _merge.mergeSeries(
        fresh,
        shown,
        removed: gates.removed(ContentKind.series),
      );
    }
    // Premier passage depuis les empreintes : le catalogue vient d'avant
    // l'exclusion des lignes de séparation.
    if (gates.hadUnhashed) {
      await _merge.removeHeaderEntries(shown, const TitleCleaner());
    }
  }

  /// Retire un catalogue qui ne sera pas affiché. S'il résiste, le prochain
  /// import le retirera parmi les orphelins : son échec ne doit pas masquer
  /// l'erreur qui a mené ici.
  Future<void> _discard(int catalogId) async {
    try {
      await _maintenance.purge(catalogId);
    } on Object {
      // Voir ci-dessus.
    }
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

/// Graine et multiplicateur de l'empreinte de la liste des chaînes.
const int _liveSeed = 0x84222325cbf29ce4;
const int _liveMix = 0x100000001b3;

/// Ce que la synchronisation sait du catalogue affiché : l'empreinte de
/// chaque film et de chaque série, et celle de la liste des chaînes. Les
/// portes qu'elle ouvre laissent passer ce qui a changé, et notent ce qui a
/// été vu pour retirer le reste.
final class _SyncGates {
  _SyncGates._(this._known, this._liveBefore);

  static Future<_SyncGates> load(
    CatalogMergeDao merge,
    int sourceId,
    int shown,
  ) async => _SyncGates._({
    ContentKind.movie: await merge.hashesOf(shown, ContentKind.movie),
    ContentKind.series: await merge.hashesOf(shown, ContentKind.series),
  }, await merge.liveHashOf(sourceId));

  final Map<ContentKind, Map<String, int?>> _known;
  final int? _liveBefore;
  final Map<ContentKind, Set<String>> _seen = {};

  /// Films affichés sans empreinte, avec celle qu'ils viennent de recevoir.
  final List<(String, int)> unhashedMovies = [];

  /// Le catalogue affiché avait des titres sans empreinte : il vient d'avant
  /// elles.
  bool get hadUnhashed =>
      _known.values.any((hashes) => hashes.values.any((hash) => hash == null));
  int _live = _liveSeed;
  int? _liveFinal;

  /// Porte d'une section. Celle des chaînes ne laisse rien passer : elle
  /// résume la liste, qui ne se télécharge à nouveau que si elle a changé.
  EntryGate gateFor(ContentKind kind) {
    if (kind == ContentKind.live) {
      return (identity, hash) {
        _live = (_live ^ hash) * _liveMix;
        return false;
      };
    }
    final known = _known[kind] ?? const <String, int?>{};
    final seen = _seen[kind] ??= <String>{};
    return (identity, hash) {
      seen.add(identity);
      final before = known[identity];
      // Un film d'avant les empreintes est tenu pour inchangé : le traiter
      // ralentirait toute la première synchronisation. Une série, elle,
      // l'est toujours, pour ne pas manquer ses nouveaux épisodes.
      if (before == null &&
          kind == ContentKind.movie &&
          known.containsKey(identity)) {
        unhashedMovies.add((identity, hash));
        return false;
      }
      return before != hash;
    };
  }

  /// La liste des chaînes a été lue en entier.
  void finishLive() => _liveFinal = _live;

  int get liveHash => _liveFinal ?? _live;

  bool get liveChanged => liveHash != _liveBefore;

  /// Une section reprise repart de zéro.
  void forget(ContentKind? kind) {
    if (kind == ContentKind.live) {
      if (_liveFinal == null) _live = _liveSeed;
    } else {
      _seen[kind]?.clear();
      if (kind == ContentKind.movie) unhashedMovies.clear();
    }
  }

  /// Identités affichées que la section n'a plus envoyées.
  List<String> removed(ContentKind kind) {
    final seen = _seen[kind] ?? const <String>{};
    return [
      for (final identity in (_known[kind] ?? const <String, int?>{}).keys)
        if (!seen.contains(identity)) identity,
    ];
  }
}
