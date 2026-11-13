import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

/// Réponse réelle de TheIntroDB pour Breaking Bad, S1E1.
const String _theIntroDbAnswer =
    '{"tvdb_id":81189,"type":"tv","season":1,"episode":1,'
    '"intro":[{"start_ms":228671,"end_ms":246465}],'
    '"credits":[{"start_ms":3432825,"end_ms":null}]}';

/// Réponse réelle d'IntroDB pour le même épisode, sans intro connue.
const String _introDbAnswer =
    '{"imdb_id":"tt0903747","media_type":"tv","is_movie":false,"season":1,'
    '"episode":1,"intro":null,"recap":null,"outro":{"start_sec":3431,'
    '"end_sec":3500,"start_ms":3431000,"end_ms":3500000,"confidence":1,'
    '"submission_count":1},"post_credits":null,"no_intro":true}';

const String _tvMazeAnswer =
    '[{"score":0.9,"show":{"name":"Breaking Bad Minisodes",'
    '"premiered":"2009-02-17","externals":{"thetvdb":1,"imdb":"tt0000001"}}},'
    '{"score":0.8,"show":{"name":"Breaking Bad","premiered":"2008-01-20",'
    '"externals":{"tvrage":18164,"thetvdb":81189,"imdb":"tt0903747"}}}]';

const SegmentQuery _query = SegmentQuery(
  title: 'Breaking Bad',
  year: 2008,
  season: 1,
  episode: 1,
);

http.Response _json(String body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(body), status);

void main() {
  group('TheIntroDbClient', () {
    test('lit l intro et le générique d un épisode', () async {
      late Uri asked;
      final client = TheIntroDbClient(
        MockClient((request) async {
          asked = request.url;
          return _json(_theIntroDbAnswer);
        }),
      );

      final segments = await client.episode(
        tmdbId: '1396',
        season: 1,
        episode: 1,
        duration: const Duration(minutes: 58),
      );

      expect(segments.intro?.start, const Duration(milliseconds: 228671));
      expect(segments.intro?.end, const Duration(milliseconds: 246465));
      expect(segments.credits?.start, const Duration(milliseconds: 3432825));
      expect(segments.credits?.end, isNull);
      expect(asked.queryParameters, {
        'tmdb_id': '1396',
        'season': '1',
        'episode': '1',
        'duration_ms': '3480000',
      });
    });

    test('n envoie qu un identifiant, TheTVDB d abord', () async {
      late Uri asked;
      final client = TheIntroDbClient(
        MockClient((request) async {
          asked = request.url;
          return _json(_theIntroDbAnswer);
        }),
      );

      await client.episode(
        tmdbId: '1396',
        tvdbId: 81189,
        season: 1,
        episode: 1,
      );

      expect(asked.queryParameters['tvdb_id'], '81189');
      expect(asked.queryParameters.containsKey('tmdb_id'), isFalse);
    });

    test('un épisode inconnu ne donne aucun passage', () async {
      final client = TheIntroDbClient(
        MockClient((_) async => _json('{"code":"no_submissions"}', 404)),
      );

      final segments = await client.episode(tmdbId: '1', season: 1, episode: 1);

      expect(segments.isEmpty, isTrue);
    });

    test('sans identifiant, ne demande rien', () async {
      final client = TheIntroDbClient(
        MockClient((_) async => fail('aucune requête attendue')),
      );

      final segments = await client.episode(season: 1, episode: 1);

      expect(segments.isEmpty, isTrue);
    });
  });

  test('IntroDbClient lit le générique et ignore l intro absente', () async {
    final client = IntroDbClient(
      MockClient((_) async => _json(_introDbAnswer)),
    );

    final segments = await client.episode(
      imdbId: 'tt0903747',
      season: 1,
      episode: 1,
    );

    expect(segments.intro, isNull);
    expect(segments.credits?.start, const Duration(seconds: 3431));
    expect(segments.credits?.end, const Duration(seconds: 3500));
  });

  group('TvMazeClient', () {
    final client = TvMazeClient(MockClient((_) async => _json(_tvMazeAnswer)));

    test('ne retient que la série du même nom et de la même année', () async {
      final ids = await client.lookup('Breaking Bad', year: 2008);

      expect(ids?.tvdbId, 81189);
      expect(ids?.imdbId, 'tt0903747');
    });

    test('une autre année ne correspond pas', () async {
      expect(await client.lookup('Breaking Bad', year: 2015), isNull);
    });
  });

  group('SegmentRepositoryImpl', () {
    SegmentRepositoryImpl repository(
      http.Response Function(Uri url) answer,
      List<Uri> calls,
    ) {
      final client = MockClient((request) async {
        calls.add(request.url);
        return answer(request.url);
      });
      return SegmentRepositoryImpl(
        theIntroDb: TheIntroDbClient(client),
        introDb: IntroDbClient(client),
        tvMaze: TvMazeClient(client),
      );
    }

    test('TheIntroDB suffit quand elle connaît tout', () async {
      final calls = <Uri>[];
      final segments = await repository((_) => _json(_theIntroDbAnswer), calls)
          .find(
            const SegmentQuery(
              title: 'Breaking Bad',
              season: 1,
              episode: 1,
              tmdbId: '1396',
            ),
          );

      expect(segments.isComplete, isTrue);
      expect(calls.map((url) => url.host), ['api.theintrodb.org']);
    });

    test(
      'sans TMDb, retrouve la série puis interroge les deux bases',
      () async {
        final calls = <Uri>[];
        final segments = await repository(
          (url) => switch (url.host) {
            'api.tvmaze.com' => _json(_tvMazeAnswer),
            'api.theintrodb.org' => _json('{"code":"no_submissions"}', 404),
            _ => _json(_introDbAnswer),
          },
          calls,
        ).find(_query);

        expect(segments.credits?.start, const Duration(seconds: 3431));
        expect(calls.map((url) => url.host), [
          'api.tvmaze.com',
          'api.theintrodb.org',
          'api.introdb.app',
        ]);
        expect(calls[1].queryParameters['tvdb_id'], '81189');
        expect(calls[2].queryParameters['imdb_id'], 'tt0903747');
      },
    );

    test('une base en panne laisse la suivante répondre', () async {
      final calls = <Uri>[];
      final segments = await repository(
        (url) => switch (url.host) {
          'api.tvmaze.com' => _json(_tvMazeAnswer),
          'api.theintrodb.org' => _json('panne', 503),
          _ => _json(_introDbAnswer),
        },
        calls,
      ).find(_query);

      expect(segments.credits, isNotNull);
    });

    test('garde la réponse pour les lectures suivantes', () async {
      final calls = <Uri>[];
      final segments = repository((_) => _json(_theIntroDbAnswer), calls);
      const query = SegmentQuery(
        title: 'Breaking Bad',
        season: 1,
        episode: 1,
        tmdbId: '1396',
      );

      await segments.find(query);
      await segments.find(query);

      expect(calls, hasLength(1));
    });

    test('redemande après une panne', () async {
      final calls = <Uri>[];
      final segments = repository((_) => _json('panne', 503), calls);
      const query = SegmentQuery(
        title: 'Lagon',
        season: 1,
        episode: 1,
        tmdbId: '7',
      );

      expect((await segments.find(query)).isEmpty, isTrue);
      final first = calls.length;
      await segments.find(query);

      expect(calls.length, greaterThan(first));
    });
  });
}
