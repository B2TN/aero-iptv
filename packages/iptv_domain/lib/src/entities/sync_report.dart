/// Étape d'une synchronisation.
enum SyncPhase {
  /// Connexion au fournisseur et préparation.
  connection,

  /// Liste d'un seul tenant, comme une playlist M3U.
  catalog,
  live,
  movies,
  series,

  /// Homonymes, versions et index de recherche.
  refinement,

  /// Application au catalogue affiché, favoris et reprises compris.
  update,

  /// Guide des programmes.
  guide,
}

/// Durée d'une étape, et ce qu'elle a vu passer.
final class SyncStep {
  const SyncStep(
    this.phase,
    this.duration, {
    this.received = 0,
    this.changed = 0,
  });

  final SyncPhase phase;
  final Duration duration;

  /// Objets reçus du fournisseur, ou programmes du guide.
  final int received;

  /// Objets nouveaux ou modifiés, donc traités.
  final int changed;
}

/// Relevé de la dernière synchronisation d'une playlist : où le temps est
/// passé, étape par étape. Il permet de comparer, sur un appareil lent, une
/// version de l'application à la suivante.
final class SyncReport {
  const SyncReport({
    required this.finishedAt,
    required this.full,
    required this.steps,
  });

  final DateTime finishedAt;

  /// Import complet, plutôt que comparaison avec le catalogue affiché.
  final bool full;
  final List<SyncStep> steps;

  Duration get total =>
      steps.fold(Duration.zero, (total, step) => total + step.duration);
}
