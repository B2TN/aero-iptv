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
  });

  final String rawName;
  final String rawGroup;
  final String? logoUrl;
}

/// Chaîne en direct.
final class LiveEntry extends CatalogEntry {
  const LiveEntry({
    required super.rawName,
    required super.rawGroup,
    required this.locator,
    super.logoUrl,
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
    this.tmdbId,
  });

  final int xtreamSeriesId;

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
  const CatalogBatch(this.entries, {this.discoveredEpgUrl});

  final List<CatalogEntry> entries;

  /// Guide annoncé par l'en-tête `#EXTM3U`.
  final String? discoveredEpgUrl;
}
