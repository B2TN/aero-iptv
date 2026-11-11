import '../common/failure.dart';
import 'content_kind.dart';

/// Phase d'une synchronisation.
enum ImportStage { connecting, catalog, indexing, epg, done }

/// Avancement d'une synchronisation, transmis depuis l'isolate d'import.
final class ImportProgress {
  const ImportProgress(
    this.stage, {
    this.section,
    this.processed = 0,
    this.epgFailed = false,
    this.failedSections = const {},
  });

  final ImportStage stage;

  /// Section en cours de téléchargement. `null` hors de la phase
  /// [ImportStage.catalog], ou si la source arrive d'un seul tenant.
  final ContentKind? section;

  /// Nombre d'entrées reçues depuis le début.
  final int processed;

  /// Le guide a échoué. Le catalogue reste valide et utilisable.
  final bool epgFailed;

  /// Sections restées en échec après plusieurs essais, avec leur cause. Les
  /// autres sont à jour, et celles-ci gardent leur contenu précédent.
  final Map<ContentKind, Failure> failedSections;
}
