import 'package:iptv_domain/iptv_domain.dart';

/// Tendances simulées : elles imposent une image large, comme le ferait TMDb.
final class FakeTrending implements TrendingRepository {
  const FakeTrending(this._baseUrl);

  final String _baseUrl;

  @override
  bool get isAvailable => true;

  @override
  Future<DateTime?> refreshedAt(String region) async => DateTime.now();

  @override
  Future<void> refresh(String region, {required String language}) async {}

  @override
  Future<List<TrendingItem>> popular(ContentKind kind, {String? region}) async {
    TrendingItem item(String title, String overview, {bool backdrop = true}) =>
        TrendingItem(
          kind: kind,
          title: title,
          originalTitle: title,
          overview: overview,
          backdropUrl: backdrop
              ? '$_baseUrl/backdrop/${title.hashCode.abs()}.jpg'
              : null,
        );
    return kind == ContentKind.series
        ? [
            item(
              'Abysses',
              'Une équipe de plongeurs découvre une cité engloutie.',
            ),
            item('Port Royal', 'Un port, trois familles et un secret.'),
          ]
        : [
            item(
              'Le Dernier Récif',
              'Un biologiste tente de sauver un récif condamné.',
            ),
            // Sans image large, le héros retombe sur l'affiche verticale.
            item(
              'Marée Haute',
              'Une ville côtière face à la tempête.',
              backdrop: false,
            ),
          ];
  }
}
