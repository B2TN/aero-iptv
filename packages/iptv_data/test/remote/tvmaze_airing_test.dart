import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

Map<String, Object?> _show(
  int id,
  String name, {
  int weight = 50,
  String type = 'Scripted',
}) => {'id': id, 'name': name, 'weight': weight, 'type': type};

/// Programme des chaînes : la série dans `show`.
Map<String, Object?> _onAir(Map<String, Object?> show) => {'show': show};

/// Programme des plateformes : la série dans `_embedded.show`.
Map<String, Object?> _online(Map<String, Object?> show) => {
  '_embedded': {'show': show},
};

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

final DateTime _now = DateTime(2026, 11, 19, 21);

void main() {
  test('classe les séries de la semaine par popularité', () async {
    final asked = <Uri>[];
    final client = MockClient((request) async {
      asked.add(request.url);
      final query = request.url.queryParameters;
      if (request.url.path == '/schedule/web') {
        return _json([
          _online(_show(1, 'Plateforme', weight: 90)),
          if (query['date'] == '2026-11-19')
            _online(_show(4, 'Journal', weight: 100, type: 'News')),
        ]);
      }
      return switch (query['country']) {
        'US' => _json([_onAir(_show(2, 'Réseau', weight: 95))]),
        // Diffusée deux jours seulement : à popularité égale, la série de
        // la plateforme, diffusée chaque jour, passe devant.
        'FR'
            when query['date'] == '2026-11-13' ||
                query['date'] == '2026-11-15' =>
          _json([_onAir(_show(3, 'Locale', weight: 90))]),
        _ => _json([]),
      };
    });

    final items = await TvMazeClient(
      client,
      pause: Duration.zero,
    ).airingThisWeek('fr', now: _now);

    // Les informations ne sont pas des séries.
    expect(items.map((item) => item.title), ['Réseau', 'Plateforme', 'Locale']);
    expect(items.first.kind, ContentKind.series);
    // Sept jours, les plateformes et trois pays.
    expect(asked, hasLength(28));
    expect(
      asked.map((url) => url.queryParameters['date']).toSet(),
      hasLength(7),
    );
    expect(asked.map((url) => url.queryParameters['country']).toSet(), {
      null,
      'US',
      'GB',
      'FR',
    });
  });

  test('passe une journée qui ne répond pas', () async {
    final client = MockClient((request) async {
      if (request.url.queryParameters['date'] == '2026-11-19') {
        return http.Response('', 503);
      }
      return _json([_onAir(_show(2, 'Réseau'))]);
    });

    final items = await TvMazeClient(
      client,
      pause: Duration.zero,
    ).airingThisWeek('US', now: _now);

    expect(items.single.title, 'Réseau');
  });

  test('signale un service muet', () {
    final client = MockClient((_) async => http.Response('', 503));

    expect(
      TvMazeClient(
        client,
        pause: Duration.zero,
      ).airingThisWeek('US', now: _now),
      throwsA(isA<ServerFailure>()),
    );
  });
}
