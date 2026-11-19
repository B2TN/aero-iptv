import '../entities/content_kind.dart';
import '../entities/trending_item.dart';

/// Service de tendances.
///
/// Ses classements sont gardés d'une actualisation à l'autre : l'accueil les
/// lit sans attendre le réseau, et ils s'actualisent en arrière-plan.
abstract interface class TrendingRepository {
  /// Vrai si un service de tendances est configuré.
  bool get isAvailable;

  /// Contenus populaires de [kind] dans [region], du plus au moins populaire,
  /// tels qu'à la dernière actualisation. Vide s'ils n'ont jamais été chargés
  /// pour ce pays.
  ///
  /// [region] est un code ISO 3166-1.
  Future<List<TrendingItem>> popular(ContentKind kind, {String? region});

  /// Instant de la dernière actualisation réussie pour [region], `null` s'il
  /// n'y en a jamais eu.
  Future<DateTime?> refreshedAt(String region);

  /// Interroge les services pour [region] et garde leurs classements. Lève une
  /// `Failure` si aucun n'a répondu : les classements précédents restent.
  ///
  /// [language] est un code ISO 639-1, pour les services qui traduisent.
  Future<void> refresh(String region, {required String language});
}
