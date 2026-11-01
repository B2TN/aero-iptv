import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

const String srt = '1\n00:00:01,000 --> 00:00:02,000\nBonjour\n';

const SubtitleQuery movieQuery = SubtitleQuery(
  contentKey: 'x:m:1',
  title: 'Inception',
  language: 'fr',
  year: 2010,
);

const SubtitleQuery episodeQuery = SubtitleQuery(
  contentKey: 'x:e:2',
  title: 'Breaking Bad',
  language: 'fr',
  season: 1,
  episode: 2,
);

Map<String, Object?> searchResponse(List<Map<String, Object?>> files) => {
  'data': [
    for (final file in files)
      {
        'attributes': {
          'files': [file],
        },
      },
  ],
};

void main() {
  group('OpenSubtitlesClient', () {
    test('envoie la clé et les critères d un film', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode(
            searchResponse([
              {'file_id': 42},
            ]),
          ),
          200,
        );
      });
      final fileId = await OpenSubtitlesClient(
        client,
        apiKey: 'cle',
      ).findBestFileId(movieQuery);

      expect(fileId, 42);
      expect(sent.url.host, 'api.opensubtitles.com');
      expect(sent.url.path, '/api/v1/subtitles');
      expect(sent.headers['Api-Key'], 'cle');
      expect(sent.headers['User-Agent'], 'AeroIPTV v0.1');
      expect(sent.url.queryParameters, {
        'languages': 'fr',
        'order_by': 'download_count',
        'order_direction': 'desc',
        'query': 'inception',
        'type': 'movie',
        'year': '2010',
      });
    });

    test('envoie la saison et l épisode', () async {
      late Uri url;
      final client = MockClient((request) async {
        url = request.url;
        return http.Response('{"data":[]}', 200);
      });
      final fileId = await OpenSubtitlesClient(
        client,
        apiKey: 'cle',
      ).findBestFileId(episodeQuery);

      expect(fileId, isNull);
      expect(url.queryParameters['type'], 'episode');
      expect(url.queryParameters['season_number'], '1');
      expect(url.queryParameters['episode_number'], '2');
      expect(url.queryParameters.containsKey('year'), isFalse);
    });

    test('ignore les résultats sans fichier', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {
                'attributes': {'files': <Object?>[]},
              },
              {
                'attributes': {
                  'files': [
                    {'file_id': '7'},
                  ],
                },
              },
            ],
          }),
          200,
        ),
      );
      expect(
        await OpenSubtitlesClient(
          client,
          apiKey: 'cle',
        ).findBestFileId(movieQuery),
        7,
      );
    });

    test('suit le lien temporaire de téléchargement', () async {
      final calls = <String>[];
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.host}');
        if (request.method == 'POST') {
          expect(jsonDecode(request.body), {
            'file_id': 42,
            'sub_format': 'srt',
          });
          return http.Response('{"link":"https://dl.example/a.srt"}', 200);
        }
        expect(request.headers.containsKey('Api-Key'), isFalse);
        return http.Response.bytes(utf8.encode(srt), 200);
      });
      final content = await OpenSubtitlesClient(
        client,
        apiKey: 'cle',
      ).download(42);

      expect(content, srt);
      expect(calls, ['POST api.opensubtitles.com', 'GET dl.example']);
    });

    test('signale un quota épuisé', () async {
      final client = MockClient((_) async => http.Response('{}', 406));
      expect(
        OpenSubtitlesClient(client, apiKey: 'cle').download(42),
        throwsA(isA<RateLimitFailure>()),
      );
    });

    test('signale une clé refusée', () async {
      final client = MockClient((_) async => http.Response('{}', 401));
      expect(
        OpenSubtitlesClient(client, apiKey: 'cle').findBestFileId(movieQuery),
        throwsA(isA<AuthFailure>()),
      );
    });

    test('rejette une réponse illisible', () async {
      final client = MockClient((_) async => http.Response('<html>', 200));
      expect(
        OpenSubtitlesClient(client, apiKey: 'cle').findBestFileId(movieQuery),
        throwsA(isA<ParseFailure>()),
      );
    });
  });

  group('SubtitleRepositoryImpl', () {
    late AppDatabase db;
    var downloads = 0;
    var now = DateTime.utc(2026);

    OpenSubtitlesClient remote() => OpenSubtitlesClient(
      MockClient((request) async {
        if (request.url.path.endsWith('/subtitles')) {
          return http.Response(
            jsonEncode(
              searchResponse([
                {'file_id': 42},
              ]),
            ),
            200,
          );
        }
        if (request.method == 'POST') {
          downloads++;
          return http.Response('{"link":"https://dl.example/a.srt"}', 200);
        }
        return http.Response.bytes(utf8.encode(srt), 200);
      }),
      apiKey: 'cle',
    );

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      downloads = 0;
      now = DateTime.utc(2026);
    });

    tearDown(() => db.close());

    test('télécharge une seule fois le même contenu', () async {
      final repository = SubtitleRepositoryImpl(db, remote());
      final first = await repository.find(movieQuery);
      final second = await repository.find(movieQuery);

      expect(first!.content, srt);
      expect(second!.content, srt);
      expect(downloads, 1);
    });

    test('distingue les langues', () async {
      final repository = SubtitleRepositoryImpl(db, remote());
      await repository.find(movieQuery);
      await repository.find(
        const SubtitleQuery(
          contentKey: 'x:m:1',
          title: 'Inception',
          language: 'en',
        ),
      );
      expect(downloads, 2);
    });

    test('reste utilisable sans clé d API', () async {
      expect(await SubtitleRepositoryImpl(db, null).find(movieQuery), isNull);
    });

    test('retrouve le cache sans clé d API', () async {
      await SubtitleRepositoryImpl(db, remote()).find(movieQuery);
      final cached = await SubtitleRepositoryImpl(db, null).find(movieQuery);
      expect(cached!.content, srt);
    });

    test('limite la taille du cache', () async {
      final repository = SubtitleRepositoryImpl(db, remote(), clock: () => now);
      for (var i = 0; i < 55; i++) {
        now = now.add(const Duration(minutes: 1));
        await repository.find(
          SubtitleQuery(contentKey: 'x:m:$i', title: 'Film', language: 'fr'),
        );
      }
      final row = await db
          .customSelect('SELECT COUNT(*) AS n FROM subtitle_cache')
          .getSingle();
      expect(row.read<int>('n'), 50);
      expect(
        await db
            .cachedSubtitle(contentKey: 'x:m:54', language: 'fr')
            .getSingleOrNull(),
        isNotNull,
      );
    });
  });
}
