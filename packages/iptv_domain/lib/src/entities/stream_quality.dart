/// Qualité déclarée d'un flux, triée de la plus faible à la plus élevée.
///
/// L'index de chaque valeur est stocké en base et sert de tri : ne pas
/// réordonner sans migration.
enum StreamQuality {
  unknown(''),
  sd('SD'),
  hd('HD'),
  fhd('FHD'),
  uhd('4K');

  const StreamQuality(this.label);

  /// Libellé affiché dans le menu de choix du flux.
  final String label;
}
