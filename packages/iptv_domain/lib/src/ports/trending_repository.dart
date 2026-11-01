import '../entities/content_kind.dart';
import '../entities/trending_item.dart';

/// Service de tendances.
abstract interface class TrendingRepository {
  /// Vrai si le service est configuré.
  bool get isAvailable;

  /// Contenus populaires de [kind], classés du plus au moins populaire.
  ///
  /// [language] est un code ISO 639-1. [region] est un code ISO 3166-1 qui
  /// oriente le classement vers les tendances locales.
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    required String language,
    String? region,
  });
}
