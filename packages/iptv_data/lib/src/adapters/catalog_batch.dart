import 'package:iptv_domain/iptv_domain.dart';

/// Entrée brute au format commun à toutes les sources.
///
/// Les adapters ne nettoient rien : ils traduisent seulement le format du
/// fournisseur. Toutes les règles Regex s'appliquent après cette frontière.
sealed class CatalogEntry {
  const CatalogEntry({
    required this.rawName,
    required this.rawGroup,
    this.logoUrl,
    this.sourceHash,
    this.position,
  });

  final String rawName;
  final String rawGroup;
  final String? logoUrl;

  /// Place dans la liste du fournisseur, quand l'adapter la connaît : une
  /// synchronisation qui saute les entrées inchangées garde ainsi l'ordre.
  final int? position;

  /// Empreinte de l'objet tel que le fournisseur l'a envoyé : la
  /// synchronisation suivante saute l'entrée si elle n'a pas changé.
  final int? sourceHash;
}

/// Chaîne en direct.
final class LiveEntry extends CatalogEntry {
  const LiveEntry({
    required super.rawName,
    required super.rawGroup,
    required this.locator,
    super.logoUrl,
    super.sourceHash,
    super.position,
    this.tvgId,
    this.tvgCountry,
  });

  final StreamLocator locator;
  final String? tvgId;
  final String? tvgCountry;
}

/// Film.
final class MovieEntry extends CatalogEntry {
  const MovieEntry({
    required super.rawName,
    required super.rawGroup,
    required this.locator,
    super.logoUrl,
    super.sourceHash,
    super.position,
  });

  final StreamLocator locator;
}

/// Série Xtream. Ses épisodes sont chargés à la première ouverture.
final class SeriesEntry extends CatalogEntry {
  const SeriesEntry({
    required super.rawName,
    required super.rawGroup,
    required this.xtreamSeriesId,
    super.logoUrl,
    super.sourceHash,
    super.position,
    this.tmdbId,
    this.lastModified,
  });

  final int xtreamSeriesId;

  /// Dernière modification annoncée par le panneau, en secondes depuis 1970.
  final int? lastModified;

  /// Identifiant TMDb fourni par le panneau, s'il en donne un.
  final String? tmdbId;
}

/// Épisode M3U. Sa série se déduit de son nom.
final class EpisodeEntry extends CatalogEntry {
  const EpisodeEntry({
    required super.rawName,
    required super.rawGroup,
    required this.locator,
    super.logoUrl,
  });

  final StreamLocator locator;
}

/// Lot d'entrées, dont la taille borne la mémoire utilisée par l'import.
final class CatalogBatch {
  const CatalogBatch(this.entries, {this.discoveredEpgUrl, int? received})
    : _received = received;

  final List<CatalogEntry> entries;
  final int? _received;

  /// Objets reçus du fournisseur pour ce lot, entrées sautées comprises.
  int get received => _received ?? entries.length;

  /// Guide annoncé par l'en-tête `#EXTM3U`.
  final String? discoveredEpgUrl;
}
