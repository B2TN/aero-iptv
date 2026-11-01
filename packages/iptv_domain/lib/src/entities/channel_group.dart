/// Groupe de chaînes de la colonne gauche de Live TV.
final class ChannelGroup {
  const ChannelGroup({
    required this.key,
    required this.displayName,
    required this.channelCount,
    this.rawGroupId,
  });

  /// Clé de fusion des groupes. Vide si le groupe ne porte que le pays et la
  /// qualité, comme « FRANCE FHD » : l'interface affiche alors un libellé
  /// générique traduit.
  final String key;
  final String displayName;
  final int channelCount;

  /// Identifiant du groupe d'origine, renseigné seulement en vue brute.
  final int? rawGroupId;
}
