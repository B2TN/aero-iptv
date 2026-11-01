import '../entities/subtitle_file.dart';

/// Service de traduction de sous-titres.
abstract interface class SubtitleTranslator {
  /// Traduit des répliques isolées, dans le même ordre.
  Future<List<String>> translateTexts(
    List<String> texts, {
    required String language,
  });

  /// Traduit [file] vers [language], un code ISO 639-1, sans changer ses temps.
  Future<SubtitleFile> translate(SubtitleFile file, {required String language});
}
