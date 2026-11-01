/// Résultat d'un téléchargement de sous-titres demandé par l'utilisateur.
enum SubtitleDownload {
  loaded,

  /// Sous-titres chargés en anglais, faute de service de traduction.
  untranslated,
  notFound,
  notConfigured,

  /// Le flux n'a que des sous-titres dessinés en images, donc rien à traduire.
  imagesOnly,
}

/// Critères de recherche de sous-titres.
final class SubtitleQuery {
  const SubtitleQuery({
    required this.contentKey,
    required this.title,
    required this.language,
    this.year,
    this.season,
    this.episode,
  });

  /// Identité stable du contenu, utilisée comme clé de cache.
  final String contentKey;
  final String title;

  /// Code ISO 639-1 de la langue voulue.
  final String language;
  final int? year;
  final int? season;
  final int? episode;
}

/// Sous-titres prêts à être chargés par le lecteur.
final class SubtitleFile {
  const SubtitleFile({
    required this.content,
    required this.language,
    required this.title,
  });

  /// Contenu SRT.
  final String content;
  final String language;
  final String title;
}
