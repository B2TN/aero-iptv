import '../entities/subtitle_file.dart';

/// Source de sous-titres externes.
abstract interface class SubtitleRepository {
  /// Vrai si le service de sous-titres est configuré.
  bool get isAvailable;

  /// Retourne les meilleurs sous-titres pour [query], ou `null` s'il n'y en a
  /// aucun ou si le service n'est pas configuré.
  Future<SubtitleFile?> find(SubtitleQuery query);

  /// Conserve [file], pour ne pas le télécharger ou le traduire à nouveau.
  Future<void> remember(SubtitleQuery query, SubtitleFile file);
}
