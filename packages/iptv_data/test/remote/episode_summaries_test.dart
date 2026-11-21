import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:test/test.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

void main() {
  group('résumés d épisodes', () {
    final asked = <Uri>[];

    /// TMDB décrit les épisodes 1 et 2 en français, le 3 seulement en anglais.
    http.Response tmdb(http.Request request) {
      asked.add(request.url);
      final path = request.url.path;
      final language = request.url.queryParameters['language'];
      if (path == '/3/search/tv') {
        return _json({
          'results': [
            {'id': 1399, 'name': 'Abysses'},
          ],
        });
      }
      if (path == '/3/tv/1399/season/1') {
        return _json({
          'episodes': [
            {
              'episode_number': 1,
              'overview': language == 'fr' ? 'La marée monte.' : 'Tide.',
            },
            {
              'episode_number': 2,
              'overview': language == 'fr' ? 'Le phare.' : 'Lighthouse.',
            },
            {
              'episode_number': 3,
              'overview': language == 'fr' ? '' : 'The village is gone.',
            },
          ],
        });
      }
      return _json({'status_message': 'not found'}, 404);
    }

    EpisodeSummaryRepositoryImpl repository(
      http.Response Function(http.Request) answer, {
      bool withTmdb = true,
    }) {
      final client = MockClient((request) async => answer(request));
      return EpisodeSummaryRepositoryImpl(
        tmdb: withTmdb ? TmdbClient(client, readToken: 'jeton') : null,
        tvMaze: TvMazeClient(client),
      );
    }

    setUp(asked.clear);

    test('dans la langue de l appli, sinon en anglais', () async {
      final summaries = await repository(
        tmdb,
      ).seasonSummaries(title: 'Abysses', season: 1, language: 'fr');
      expect(summaries, {
        1: 'La marée monte.',
        2: 'Le phare.',
        3: 'The village is gone.',
      });
    });

    test('l identifiant du fournisseur évite la recherche', () async {
      await repository(tmdb).seasonSummaries(
        title: 'Abysses',
        tmdbId: '1399',
        season: 1,
        language: 'en',
      );
      expect(asked.map((uri) => uri.path), ['/3/tv/1399/season/1']);
    });

    test('une saison n est demandée qu une fois par session', () async {
      final summaries = repository(tmdb);
      for (var i = 0; i < 2; i++) {
        await summaries.seasonSummaries(
          title: 'Abysses',
          tmdbId: '1399',
          season: 1,
          language: 'en',
        );
      }
      expect(asked, hasLength(1));
    });

    test('une saison inconnue de TMDB ne donne rien, sans erreur', () async {
      final summaries = await repository(tmdb).seasonSummaries(
        title: 'Abysses',
        tmdbId: '1399',
        season: 7,
        language: 'fr',
      );
      expect(summaries, isEmpty);
    });

    test('sans clé TMDB, TVmaze donne les résumés en anglais', () async {
      http.Response tvMaze(http.Request request) => switch (request.url.path) {
        '/search/shows' => _json([
          {
            'show': {'id': 7, 'name': 'Abysses', 'premiered': '2026-01-04'},
          },
        ]),
        '/shows/7/episodes' => _json([
          {
            'season': 1,
            'number': 1,
            'summary': '<p>The <b>tide</b> rises.</p>',
          },
          {'season': 2, 'number': 1, 'summary': '<p>Later.</p>'},
          {'season': 1, 'number': 2, 'summary': null},
        ]),
        _ => _json({}, 404),
      };

      final summaries = await repository(
        tvMaze,
        withTmdb: false,
      ).seasonSummaries(title: 'Abysses', season: 1, language: 'fr');
      expect(summaries, {1: 'The tide rises.'});
    });

    test('le texte d un résumé TVmaze', () {
      expect(
        TvMazeClient.plainSummary('<p>Tom &amp; Lou<br/>partent.</p>'),
        'Tom & Lou partent.',
      );
      expect(TvMazeClient.plainSummary('<p></p>'), isNull);
    });
  });
}
