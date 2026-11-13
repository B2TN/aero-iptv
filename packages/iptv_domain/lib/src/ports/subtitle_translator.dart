/// Service de traduction de sous-titres.
abstract interface class SubtitleTranslator {
  /// Traduit des répliques isolées vers [language], un code ISO 639-1, dans le
  /// même ordre.
  Future<List<String>> translateTexts(
    List<String> texts, {
    required String language,
  });
}
