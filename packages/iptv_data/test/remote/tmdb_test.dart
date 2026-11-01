import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

void main() {
  test('lit les films populaires d une région', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'results': [
              {
                'title': 'Le Titre',
                'original_title': 'The Title',
                'overview': 'Résumé',
                'poster_path': '/p.jpg',
                'backdrop_path': '/b.jpg',
              },
              {'title': ''},
            ],
          }),
        ),
        200,
      );
    });
    final items = await TmdbClient(
      client,
      readToken: 'jeton',
    ).popular(ContentKind.movie, language: 'fr', region: 'FR');

    expect(sent.url.path, '/3/movie/popular');
    expect(sent.url.queryParameters, {'language': 'fr', 'region': 'FR'});
    expect(sent.headers['Authorization'], 'Bearer jeton');
    final item = items.single;
    expect(item.title, 'Le Titre');
    expect(item.originalTitle, 'The Title');
    expect(item.posterUrl, 'https://image.tmdb.org/t/p/w342/p.jpg');
    expect(item.backdropUrl, 'https://image.tmdb.org/t/p/w780/b.jpg');
  });

  test('lit les noms des séries, sans région', () async {
    late Uri url;
    final client = MockClient((request) async {
      url = request.url;
      return http.Response(
        jsonEncode({
          'results': [
            {'name': 'Dark', 'original_name': 'Dark'},
          ],
        }),
        200,
      );
    });
    final items = await TmdbClient(
      client,
      readToken: 'jeton',
    ).popular(ContentKind.series, language: 'fr', region: 'FR');

    expect(url.path, '/3/tv/popular');
    expect(url.queryParameters.containsKey('region'), isFalse);
    expect(items.single.kind, ContentKind.series);
  });

  test('reste vide sans jeton', () async {
    const repository = TrendingRepositoryImpl(null);
    expect(repository.isAvailable, isFalse);
    expect(
      await repository.popular(ContentKind.movie, language: 'fr'),
      isEmpty,
    );
  });

  test('rejette une réponse illisible', () {
    final client = MockClient((_) async => http.Response('<html>', 200));
    expect(
      TmdbClient(
        client,
        readToken: 'x',
      ).popular(ContentKind.movie, language: 'fr'),
      throwsA(isA<ParseFailure>()),
    );
  });
}
