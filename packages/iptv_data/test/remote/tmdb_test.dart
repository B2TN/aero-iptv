import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

Map<String, Object?> _movie(int id, String title, {String? original}) => {
  'id': id,
  'title': title,
  'original_title': original ?? title,
  'overview': 'Résumé de $title',
  'poster_path': '/p$id.jpg',
  'backdrop_path': '/b$id.jpg',
};

http.Response _page(List<Map<String, Object?>> results) =>
    http.Response.bytes(utf8.encode(jsonEncode({'results': results})), 200);

final DateTime _now = DateTime(2026, 11, 20, 9);

void main() {
  test('la semaine d abord, si on peut la regarder dans le pays', () async {
    final asked = <Uri>[];
    final client = MockClient((request) async {
      asked.add(request.url);
      final page = request.url.queryParameters['page'];
      if (page != '1') return _page(const []);
      return request.url.path.startsWith('/3/trending/')
          // Mondial : 3 n'est pas proposé dans le pays.
          ? _page([
              _movie(2, 'Beta', original: 'Beta Original'),
              _movie(3, 'Gamma'),
            ])
          : _page([
              _movie(1, 'Alpha'),
              _movie(2, 'Beta', original: 'Beta Original'),
            ]);
    });

    final items = await TmdbClient(
      client,
      readToken: 'jeton',
    ).trending(ContentKind.movie, language: 'fr', region: 'FR', now: _now);

    expect(items.map((item) => item.title), ['Beta', 'Alpha']);
    final first = items.first;
    expect(first.kind, ContentKind.movie);
    expect(first.originalTitle, 'Beta Original');
    expect(first.posterUrl, 'https://image.tmdb.org/t/p/w342/p2.jpg');
    expect(first.backdropUrl, 'https://image.tmdb.org/t/p/w1280/b2.jpg');
    expect(first.overview, 'Résumé de Beta');

    final discover = asked.firstWhere((url) => url.path == '/3/discover/movie');
    expect(discover.queryParameters, {
      'language': 'fr',
      'watch_region': 'FR',
      'with_watch_monetization_types': 'flatrate|free|ads|rent|buy',
      'sort_by': 'popularity.desc',
      'primary_release_date.gte': '2024-11-20',
      'page': '1',
    });
    expect(asked.map((url) => url.path).toSet(), {
      '/3/discover/movie',
      '/3/trending/movie/week',
    });
  });

  test('une série doit avoir eu un épisode depuis deux mois', () async {
    late Uri discover;
    late http.BaseRequest sent;
    final client = MockClient((request) async {
      sent = request;
      if (request.url.path == '/3/discover/tv') discover = request.url;
      return _page([
        {'id': 7, 'name': 'Dark', 'original_name': 'Dark'},
      ]);
    });

    final items = await TmdbClient(
      client,
      readToken: 'jeton',
    ).trending(ContentKind.series, language: 'en', region: 'GB', now: _now);

    expect(items.single.title, 'Dark');
    expect(items.single.kind, ContentKind.series);
    expect(discover.queryParameters['air_date.gte'], '2026-09-21');
    expect(discover.queryParameters['watch_region'], 'GB');
    expect(sent.headers['Authorization'], 'Bearer jeton');
  });

  test('rejette une réponse illisible', () {
    final client = MockClient((_) async => http.Response('<html>', 200));
    expect(
      TmdbClient(
        client,
        readToken: 'x',
      ).trending(ContentKind.movie, language: 'fr', region: 'FR', now: _now),
      throwsA(isA<ParseFailure>()),
    );
  });
}
