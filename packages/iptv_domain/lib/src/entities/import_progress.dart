/// Phase d'une synchronisation.
enum ImportStage { connecting, catalog, indexing, epg, done }

/// Avancement d'une synchronisation, transmis depuis l'isolate d'import.
final class ImportProgress {
  const ImportProgress(
    this.stage, {
    this.processed = 0,
    this.epgFailed = false,
  });

  final ImportStage stage;

  /// Nombre d'entrées traitées dans la phase en cours.
  final int processed;

  /// Le guide a échoué. Le catalogue reste valide et utilisable.
  final bool epgFailed;
}
