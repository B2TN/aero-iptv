import '../ports/trending_repository.dart';

/// Actualise les tendances au plus une fois par jour.
final class RefreshTrending {
  RefreshTrending(this._trending, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Âge au-delà duquel les classements sont redemandés. Un peu moins d'un
  /// jour : une TV allumée chaque soir à la même heure les actualise chaque
  /// soir.
  static const Duration maxAge = Duration(hours: 20);

  final TrendingRepository _trending;
  final DateTime Function() _clock;

  /// Actualise les tendances de [region] si elles ont plus de [maxAge], ou si
  /// elles n'ont jamais été chargées. Vrai si elles l'ont été. Lève une
  /// `Failure` si aucun service n'a répondu.
  Future<bool> call(String region, {required String language}) async {
    if (!_trending.isAvailable) return false;
    final last = await _trending.refreshedAt(region);
    if (last != null && _clock().difference(last) < maxAge) return false;
    await _trending.refresh(region, language: language);
    return true;
  }
}
