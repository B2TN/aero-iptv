/// Résultat d'une demande de sous-titres faite par l'utilisateur.
enum SubtitleOutcome {
  /// Une piste du flux s'affiche, dans la langue voulue ou traduite.
  loaded,

  /// Le flux n'a aucune piste de sous-titres à afficher ou à traduire.
  none,

  /// Le flux n'a que des sous-titres dessinés en images, donc rien à traduire.
  imagesOnly,
}
