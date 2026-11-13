import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

/// Recherche TVmaze : un homonyme d'une autre année, puis la bonne série.
String _search({String status = 'Running'}) => jsonEncode([
  {
    'show': {'id': 1, 'name': 'Abysses', 'premiered': '1998-03-01'},
  },
  {
    'show': {
      'id': 42,
      'name': 'Abysses',
      'premiered': '2024-09-12',
      'status': status,
    },
  },
]);

/// Épisodes de la série 42, dans le désordre, au format de TVmaze.
final String _episodes = jsonEncode([
  {
    'season': 2,
    'number': 4,
    'name': 'Le retour',
    'airdate': '2026-11-13',
    'airstamp': '2026-11-13T20:00:00+00:00',
  },
  {
    'season': 2,
    'number': 6,
    'name': 'TBA',
    'airdate': '2026-11-27',
    'airstamp': '2026-11-27T20:00:00+00:00',
  },
  {
    'season': 2,
    'number': 5,
    'name': 'Les épaves',
    'airdate': '2026-11-20',
    'airstamp': '2026-11-20T20:00:00+00:00',
  },
  // Annoncé sans date : rien à montrer.
  {'season': 2, 'number': 7, 'name': 'Episode 7', 'airdate': ''},
]);

/// Le 13 novembre 2026 à 21 h UTC : l'épisode 4 vient de passer.
final DateTime _now = DateTime.utc(2026, 11, 13, 21);

http.Response _json(String body) => http.Response.bytes(utf8.encode(body), 200);

void main() {
  group('TvMazeClient.schedule', () {
    test(
      'donne les prochains épisodes, du plus proche au plus lointain',
      () async {
        final paths = <String>[];
        final client = TvMazeClient(
          MockClient((request) async {
            paths.add(request.url.path);
            return _json(
              request.url.path == '/search/shows' ? _search() : _episodes,
            );
          }),
        );

        final schedule = await client.schedule(
          'Abysses',
          year: 2024,
          now: _now,
        );

        expect(schedule?.running, isTrue);
        expect(
          [for (final episode in schedule!.upcoming) episode.number],
          [5, 6],
        );
        expect(schedule.upcoming.first.title, 'Les épaves');
        expect(schedule.upcoming.first.airDate, DateTime(2026, 11, 20));
        // « TBA » n'est pas un titre.
        expect(schedule.upcoming.last.title, isNull);
        expect(paths, ['/search/shows', '/shows/42/episodes']);
      },
    );

    test('une série terminée n annonce rien, sans lire ses épisodes', () async {
      final paths = <String>[];
      final client = TvMazeClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return _json(_search(status: 'Ended'));
        }),
      );

      final schedule = await client.schedule('Abysses', year: 2024, now: _now);

      expect(schedule?.running, isFalse);
      expect(schedule?.upcoming, isEmpty);
      expect(paths, ['/search/shows']);
    });

    test('un nom approchant ne suffit pas', () async {
      final client = TvMazeClient(MockClient((_) async => _json(_search())));

      expect(await client.schedule('Abysse', now: _now), isNull);
      expect(await client.schedule('Abysses', year: 2020, now: _now), isNull);
    });
  });

  group('ScheduleRepositoryImpl', () {
    test('garde le calendrier quelques heures', () async {
      var requests = 0;
      var now = _now;
      final repository = ScheduleRepositoryImpl(
        TvMazeClient(
          MockClient((request) async {
            requests++;
            return _json(
              request.url.path == '/search/shows' ? _search() : _episodes,
            );
          }),
        ),
        clock: () => now,
      );

      await repository.scheduleOf('Abysses', year: 2024);
      await repository.scheduleOf('Abysses', year: 2024);
      expect(requests, 2);

      now = now.add(const Duration(hours: 7));
      await repository.scheduleOf('Abysses', year: 2024);
      expect(requests, 4);
    });

    test('se souvient aussi d une série inconnue', () async {
      var requests = 0;
      final repository = ScheduleRepositoryImpl(
        TvMazeClient(
          MockClient((_) async {
            requests++;
            return _json('[]');
          }),
        ),
        clock: () => _now,
      );

      expect(await repository.scheduleOf('Inconnue'), isNull);
      expect(await repository.scheduleOf('Inconnue'), isNull);
      expect(requests, 1);
    });

    test('signale un service injoignable', () async {
      final repository = ScheduleRepositoryImpl(
        TvMazeClient(MockClient((_) async => http.Response('', 503))),
        clock: () => _now,
      );

      await expectLater(
        repository.scheduleOf('Abysses'),
        throwsA(isA<Failure>()),
      );
    });
  });
}
