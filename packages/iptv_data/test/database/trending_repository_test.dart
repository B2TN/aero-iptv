import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

/// Classement Apple : des noms, avec saison et langue à retirer.
http.Response _chart(List<String> names) => _json({
  'feed': {
    'entry': [
      for (final name in names)
        {
          'im:name': {'label': name},
        },
    ],
  },
});

/// Services simulés. [down] les rend muets.
final class _Services {
  bool down = false;
  List<String> movies = ['Obsession'];

  http.Client get client => MockClient((request) async {
    if (down) return http.Response('', 503);
    final path = request.url.path;
    if (request.url.host == 'api.themoviedb.org') {
      final isMovie = path.contains('movie');
      return _json({
        'results': request.url.queryParameters['page'] == '1'
            ? [
                isMovie
                    ? {'id': 1, 'title': 'Dune', 'original_title': 'Dune'}
                    : {'id': 2, 'name': 'Andor', 'original_name': 'Andor'},
              ]
            : <Map<String, Object?>>[],
      });
    }
    if (path.contains('/topmovies/')) return _chart(movies);
    // Le classement du pays, puis celui des États-Unis.
    return _chart(
      path.startsWith('/fr/')
          ? ['Andor, Saison 2 (VF)', 'Lupin, Saison 3']
          : ['Severance, Season 2'],
    );
  });
}

void main() {
  late AppDatabase db;
  late _Services services;
  var now = DateTime(2026, 11, 19, 20);

  TrendingRepositoryImpl repository({bool tmdb = false}) =>
      TrendingRepositoryImpl(
        db,
        tmdb: tmdb ? TmdbClient(services.client, readToken: 'jeton') : null,
        charts: AppleChartsClient(services.client, clock: () => now),
        clock: () => now,
      );

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: configureConnection),
        closeStreamsSynchronously: true,
      ),
    );
    services = _Services();
    now = DateTime(2026, 11, 19, 20);
  });

  tearDown(() => db.close());

  test('sans service, rien à montrer ni à actualiser', () async {
    final none = TrendingRepositoryImpl(db);

    expect(none.isAvailable, isFalse);
    expect(await none.popular(ContentKind.movie, region: 'FR'), isEmpty);
    expect(await none.refreshedAt('FR'), isNull);
  });

  test('sans jeton TMDB, garde les classements Apple du pays', () async {
    final trending = repository();
    expect(await trending.popular(ContentKind.series, region: 'FR'), isEmpty);

    await trending.refresh('FR', language: 'fr');

    // Le pays, puis les États-Unis, une fois chacune.
    expect(
      (await trending.popular(
        ContentKind.series,
        region: 'FR',
      )).map((item) => item.title),
      ['Andor', 'Lupin', 'Severance'],
    );
    expect(
      (await trending.popular(
        ContentKind.movie,
        region: 'FR',
      )).map((item) => item.title),
      ['Obsession'],
    );
    expect(await trending.refreshedAt('FR'), now);
    // Un autre pays n'a rien de chargé.
    expect(await trending.popular(ContentKind.movie, region: 'BE'), isEmpty);
    expect(await trending.refreshedAt('BE'), isNull);
  });

  test('avec un jeton, les tendances viennent de TMDB, rechargées', () async {
    await repository().refresh('FR', language: 'fr');
    final trending = repository(tmdb: true);
    // Les classements d'Apple ne valent pas pour TMDB.
    expect(await trending.refreshedAt('FR'), isNull);

    await trending.refresh('FR', language: 'fr');

    expect(
      (await trending.popular(
        ContentKind.movie,
        region: 'FR',
      )).map((item) => item.title),
      ['Dune'],
    );
    expect(
      (await trending.popular(
        ContentKind.series,
        region: 'FR',
      )).map((item) => item.title),
      ['Andor'],
    );
  });

  test('un nouveau pays remplace l ancien', () async {
    final trending = repository();
    await trending.refresh('FR', language: 'fr');

    await trending.refresh('BE', language: 'fr');

    expect(await trending.refreshedAt('FR'), isNull);
    expect(await trending.popular(ContentKind.movie, region: 'BE'), isNotEmpty);
  });

  test('sans réponse, les classements précédents restent', () async {
    final trending = repository();
    await trending.refresh('FR', language: 'fr');
    final before = now;
    now = now.add(const Duration(days: 1));
    services.down = true;

    await expectLater(
      trending.refresh('FR', language: 'fr'),
      throwsA(isA<Failure>()),
    );

    expect(await trending.refreshedAt('FR'), before);
    expect(
      (await trending.popular(
        ContentKind.movie,
        region: 'FR',
      )).map((item) => item.title),
      ['Obsession'],
    );
  });

  test('une actualisation remplace le classement', () async {
    final trending = repository();
    await trending.refresh('FR', language: 'fr');
    services.movies = ['Dune', 'Wicked'];
    // Le classement Apple garde ses réponses une demi-heure.
    now = now.add(const Duration(days: 1));

    await trending.refresh('FR', language: 'fr');

    expect(
      (await trending.popular(
        ContentKind.movie,
        region: 'FR',
      )).map((item) => item.title),
      ['Dune', 'Wicked'],
    );
  });
}
