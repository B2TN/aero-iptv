import 'package:iptv_domain/iptv_domain.dart';

import '../remote/apple_charts_client.dart';
import '../remote/tmdb_client.dart';

/// Tendances TMDb si un jeton est configuré, sinon classements Apple.
final class TrendingRepositoryImpl implements TrendingRepository {
  /// [client] est `null` tant qu'aucun jeton n'est configuré.
  const TrendingRepositoryImpl(this._client, {AppleChartsClient? charts})
    : _charts = charts;

  final TmdbClient? _client;
  final AppleChartsClient? _charts;

  @override
  bool get isAvailable => _client != null || _charts != null;

  @override
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    required String language,
    String? region,
  }) async {
    final client = _client;
    if (client != null) {
      return client.popular(kind, language: language, region: region);
    }
    return _charts?.popular(kind, region: region) ?? const [];
  }
}
