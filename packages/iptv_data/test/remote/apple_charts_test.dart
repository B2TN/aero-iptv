import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

http.Response _chart(List<String> names) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'feed': {
        'entry': [
          for (final name in names)
            {
              'im:name': {'label': name},
            },
        ],
      },
    }),
  ),
  200,
);

void main() {
  test('nettoie les titres et complète avec le classement américain', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.path);
      return request.url.path.startsWith('/fr/')
          ? _chart(['Normal People, Saison 1 (VF)', 'Gotham, Saison 2'])
          : _chart(['Gotham, Season 2', 'Andor, Season 1']);
    });

    final items = await AppleChartsClient(
      client,
    ).popular(ContentKind.series, region: 'FR');

    expect(items.map((item) => item.title), [
      'Normal People',
      'Gotham',
      'Andor',
    ]);
    expect(items.first.kind, ContentKind.series);
    expect(urls, contains('/fr/rss/toptvseasons/limit=100/json'));
  });

  test('ne redemande pas le classement à chaque ouverture', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return _chart(['Obsession']);
    });
    final charts = AppleChartsClient(client);

    await charts.popular(ContentKind.movie, region: 'US');
    await charts.popular(ContentKind.movie, region: 'US');

    expect(calls, 1);
  });

  test('sert de repli quand aucun jeton TMDb n est configuré', () async {
    final client = MockClient((_) async => _chart(['Obsession']));
    final repository = TrendingRepositoryImpl(
      null,
      charts: AppleChartsClient(client),
    );

    expect(repository.isAvailable, isTrue);
    final items = await repository.popular(
      ContentKind.movie,
      language: 'fr',
      region: 'US',
    );
    expect(items.single.title, 'Obsession');
  });
}
