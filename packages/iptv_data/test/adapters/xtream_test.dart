import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/src/adapters/catalog_batch.dart';
import 'package:iptv_data/src/adapters/playlist_source_adapter.dart';
import 'package:iptv_data/src/adapters/xtream/json_array_stream.dart';
import 'package:iptv_data/src/adapters/xtream/xtream_api_client.dart';
import 'package:iptv_data/src/adapters/xtream/xtream_dtos.dart';
import 'package:iptv_data/src/adapters/xtream/xtream_source_adapter.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

const credentials = XtreamCredentials(
  serverUrl: 'http://s.example:8080',
  username: 'jean',
  password: 'secret',
);

/// Simule un panneau Xtream, dont les champs changent de type selon les routes.
http.Response panel(http.Request request) {
  final action = request.url.queryParameters['action'];
  final Object body = switch (action) {
    null => {
      'user_info': {'auth': 1, 'status': 'Active'},
    },
    'get_live_categories' => [
      {'category_id': '1', 'category_name': 'FR | SPORTS'},
    ],
    'get_live_streams' => [
      {
        'name': 'FR: beIN Sports 1 FHD',
        'stream_id': 11,
        'stream_icon': 'http://l/b.png',
        'epg_channel_id': 'bein1.fr',
        'category_id': '1',
      },
      {'name': 'Sans identifiant'},
    ],
    'get_vod_categories' => [
      {'category_id': 2, 'category_name': 'VOD FR'},
    ],
    'get_vod_streams' => [
      {
        'name': 'FR - Inception (2010)',
        'stream_id': '22',
        'container_extension': 'mkv',
        'category_id': 2,
      },
    ],
    'get_series_categories' => <Object?>[],
    'get_series' => [
      {'name': 'FR - Lost', 'series_id': 33, 'cover': 'http://l/l.png'},
    ],
    _ => <Object?>[],
  };
  return http.Response(jsonEncode(body), 200);
}

void main() {
  group('JsonArraySplitter', () {
    List<String> split(List<String> chunks) {
      final splitter = JsonArraySplitter();
      return [for (final chunk in chunks) ...splitter.add(chunk)];
    }

    test('découpe un tableau en objets', () {
      expect(split(['[{"a":1},{"b":2}]']), ['{"a":1}', '{"b":2}']);
    });

    test('reconstitue un objet réparti sur plusieurs fragments', () {
      expect(split(['[{"a"', ':"x', 'y"},', '{"b":2}', ']']), [
        '{"a":"xy"}',
        '{"b":2}',
      ]);
    });

    test('ignore accolades et guillemets échappés dans une chaîne', () {
      const object = r'{"a":"}{\"[]"}';
      expect(split(['[$object]']), [object]);
    });

    test('gère un échappement coupé entre deux fragments', () {
      expect(split([r'[{"a":"x\', r'"y"}]']), [r'{"a":"x\"y"}']);
    });

    test('conserve les objets imbriqués', () {
      expect(split(['[{"a":{"b":[1,{"c":2}]}}]']), ['{"a":{"b":[1,{"c":2}]}}']);
    });

    test('traite {} comme un tableau vide', () {
      expect(split(['{}']), isEmpty);
    });

    test('lit un objet indexé comme une liste', () {
      // PHP encode ainsi un tableau dont les indices ont des trous.
      expect(split(['{"0":{"a":1},"2":{"b":"}"},"n":3}']), [
        '{"a":1}',
        '{"b":"}"}',
      ]);
    });

    test('lit un objet indexé coupé au milieu d une clé', () {
      expect(split(['{"1', '0":{"a"', ':1}}']), ['{"a":1}']);
    });

    test('rejette une page HTML', () {
      expect(() => split(['<html>']), throwsFormatException);
    });

    test('rejette la réponse de connexion reçue à la place d une liste', () {
      expect(
        () => split(['{"user_info":{"auth":0},"server_info":{}}']),
        throwsFormatException,
      );
      expect(
        () => split(['{"user_', 'info":{"auth":1}}']),
        throwsFormatException,
      );
    });

    test('rejette un message d erreur', () {
      expect(
        () => split(['{"status":"error","message":"user_info"}']),
        throwsFormatException,
      );
    });

    test('une valeur ne passe pas pour une clé', () {
      expect(split(['{"a":"user_info","b":{"c":1}}']), ['{"c":1}']);
    });

    test('sait si la liste est allée à son terme', () {
      final cut = JsonArraySplitter()..add('[{"a":1},{"b"');
      final whole = JsonArraySplitter()..add('[{"a":1}]');
      final empty = JsonArraySplitter()..add('  ');

      expect(cut.isComplete, isFalse);
      expect(whole.isComplete, isTrue);
      expect(empty.isComplete, isFalse);
    });

    test('retourne le même résultat quel que soit le découpage', () {
      final objects = [
        for (var i = 0; i < 50; i++) {'id': i, 'name': 'é"\\ $i'},
      ];
      final json = jsonEncode(objects);
      final bySingleChar = [for (final char in json.split('')) char];
      expect(split(bySingleChar).map(jsonDecode).toList(), objects);
    });
  });

  group('decodeJsonObjects', () {
    test('signale une réponse coupée en route', () {
      expect(
        decodeJsonObjects(Stream.fromIterable(['[{"a":1},', '{"b"'])).toList(),
        throwsA(isA<TruncatedJsonException>()),
      );
    });

    test('signale une réponse vide', () {
      expect(
        decodeJsonObjects(const Stream<String>.empty()).toList(),
        throwsA(isA<TruncatedJsonException>()),
      );
    });

    test('livre les objets reçus avant la coupure', () async {
      final received = <Map<String, dynamic>>[];
      await expectLater(
        decodeJsonObjects(
          Stream.fromIterable(['[{"a":1},{"b"']),
        ).forEach(received.add),
        throwsA(isA<TruncatedJsonException>()),
      );
      expect(received, [
        {'a': 1},
      ]);
    });
  });

  group('lecteurs tolérants', () {
    test('acceptent nombre et chaîne', () {
      expect(readInt('12'), 12);
      expect(readInt(12), 12);
      expect(readInt(12.0), 12);
      expect(readInt(''), isNull);
      expect(readString(''), isNull);
      expect(readString(7), '7');
    });
  });

  group('XtreamEpisode', () {
    test('lit une table indexée par saison', () {
      final episodes = XtreamEpisode.listFromSeriesInfo({
        'episodes': {
          '2': [
            {
              'id': '5',
              'season': 2,
              'episode_num': '3',
              'title': 'Titre',
              'container_extension': 'mkv',
            },
          ],
        },
      });
      expect(episodes.single.season, 2);
      expect(episodes.single.number, 3);
    });

    test('lit une liste de listes', () {
      final episodes = XtreamEpisode.listFromSeriesInfo({
        'episodes': [
          [
            {'id': 5},
          ],
        ],
      });
      expect(episodes.single.id, 5);
    });

    test('accepte une série sans épisode', () {
      expect(
        XtreamEpisode.listFromSeriesInfo({'episodes': <Object?>[]}),
        isEmpty,
      );
    });
  });

  group('XtreamSourceAdapter', () {
    test('produit les mêmes entrées communes que le M3U', () async {
      final client = MockClient((request) async => panel(request));
      final entries = await XtreamSourceAdapter(
        client,
      ).fetch(credentials).expand((batch) => batch.entries).toList();

      final live = entries.whereType<LiveEntry>().single;
      expect(live.rawGroup, 'FR | SPORTS');
      expect(live.tvgId, 'bein1.fr');
      expect((live.locator as XtreamStream).streamId, 11);

      final movie = entries.whereType<MovieEntry>().single;
      expect(movie.rawGroup, 'VOD FR');
      expect((movie.locator as XtreamStream).extension, 'mkv');

      expect(entries.whereType<SeriesEntry>().single.xtreamSeriesId, 33);
    });

    test('rejette un compte refusé', () async {
      final client = MockClient(
        (_) async => http.Response('{"user_info":{"auth":0}}', 200),
      );
      expect(
        XtreamSourceAdapter(client).fetch(credentials).toList(),
        throwsA(isA<AuthFailure>()),
      );
    });

    group('listes illisibles', () {
      Future<List<CatalogEntry>> channelsFrom(String body) {
        final client = MockClient(
          (request) async =>
              request.url.queryParameters['action'] == 'get_live_streams'
              ? http.Response(body, 200)
              : panel(request),
        );
        return XtreamSourceAdapter(
          client,
        ).fetch(credentials).expand((batch) => batch.entries).toList();
      }

      test('une liste coupée en route est une panne de réseau', () {
        expect(
          channelsFrom('[{"name":"A","stream_id":1},{"na'),
          throwsA(isA<NetworkFailure>()),
        );
      });

      test('une réponse vide est une panne de réseau', () {
        expect(channelsFrom(''), throwsA(isA<NetworkFailure>()));
      });

      test('une page HTML est une réponse illisible', () {
        expect(
          channelsFrom('<html>Erreur 500</html>'),
          throwsA(isA<ParseFailure>()),
        );
      });

      test('la réponse de connexion n est pas une liste vide', () {
        expect(
          channelsFrom('{"user_info":{"auth":0}}'),
          throwsA(isA<ParseFailure>()),
        );
      });

      test('un élément mal formé est une réponse illisible', () {
        expect(
          channelsFrom('[{"name":"A","stream_id":1},{"name":}]'),
          throwsA(isA<ParseFailure>()),
        );
      });

      test('un objet indexé livre ses chaînes', () async {
        final entries = await channelsFrom(
          '{"1":{"name":"A","stream_id":1},"3":{"name":"B","stream_id":2}}',
        );

        expect(entries.whereType<LiveEntry>(), hasLength(2));
      });
    });

    group('erreurs du serveur', () {
      Matcher refusedWith(int status) => throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.status,
          'status',
          status,
        ),
      );

      // Statuts relevés sur un vrai panneau, qui refuse sans passer par `auth`.
      for (final status in [511, 513, 884]) {
        test('le statut $status est un refus du compte', () async {
          final client = MockClient((_) async => http.Response('', status));
          await expectLater(
            XtreamSourceAdapter(client).fetch(credentials).toList(),
            refusedWith(status),
          );
        });
      }

      for (final statusLine in ['HTTP/1.1 513 ', 'HTTP/1.1 513 <none>']) {
        test('comprend la ligne de statut "$statusLine"', () async {
          final server = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          addTearDown(server.close);
          server.listen((socket) {
            socket.listen((_) {
              socket.write(
                '$statusLine\r\n'
                'Content-Type: application/json\r\n'
                'Transfer-Encoding: chunked\r\n'
                'Connection: close\r\n\r\n0\r\n\r\n',
              );
              unawaited(socket.close());
            });
          });
          final client = http.Client();
          addTearDown(client.close);

          await expectLater(
            XtreamSourceAdapter(client)
                .fetch(
                  XtreamCredentials(
                    serverUrl: 'http://127.0.0.1:${server.port}',
                    username: 'jean',
                    password: 'secret',
                  ),
                )
                .toList(),
            refusedWith(513),
          );
        });
      }

      test('un vrai serveur HTTP accepte le bon compte seulement', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          final query = request.uri.queryParameters;
          if (query['username'] == 'jean' && query['password'] == 'secret') {
            final reply = panel(http.Request('GET', request.requestedUri));
            request.response
              ..headers.contentType = ContentType.json
              ..write(reply.body);
          } else {
            request.response.statusCode = 513;
          }
          await request.response.close();
        });
        final client = http.Client();
        addTearDown(client.close);
        final adapter = XtreamSourceAdapter(client);
        final address = 'http://127.0.0.1:${server.port}';

        final batches = await adapter
            .fetch(
              XtreamCredentials(
                serverUrl: '$address;',
                username: 'jean',
                password: 'secret',
              ),
            )
            .toList();
        expect(batches.expand((batch) => batch.entries), hasLength(3));

        await expectLater(
          adapter
              .fetch(
                XtreamCredentials(
                  serverUrl: address,
                  username: 'jean',
                  password: 'erreur-de-saisie',
                ),
              )
              .toList(),
          refusedWith(513),
        );
      });

      test('une panne du serveur ne met pas le compte en cause', () async {
        final client = MockClient((_) async => http.Response('', 503));
        await expectLater(
          XtreamSourceAdapter(client).fetch(credentials).toList(),
          throwsA(isA<ServerFailure>().having((f) => f.status, 'status', 503)),
        );
      });

      test(
        'une erreur après la connexion ne met pas le compte en cause',
        () async {
          final client = MockClient((request) async {
            final action = request.url.queryParameters['action'];
            return action == 'get_live_streams'
                ? http.Response('', 513)
                : panel(request);
          });
          await expectLater(
            XtreamSourceAdapter(client).fetch(credentials).toList(),
            throwsA(
              isA<ServerFailure>().having((f) => f.status, 'status', 513),
            ),
          );
        },
      );

      test('l absence de réponse reste une erreur réseau', () async {
        final client = MockClient(
          (_) async => throw http.ClientException('hôte inconnu'),
        );
        await expectLater(
          XtreamSourceAdapter(client).fetch(credentials).toList(),
          throwsA(isA<NetworkFailure>()),
        );
      });

      test('une adresse invalide est signalée sans planter', () async {
        final client = MockClient((_) async => http.Response('', 200));
        await expectLater(
          XtreamSourceAdapter(client)
              .fetch(
                const XtreamCredentials(
                  serverUrl: 'http://[adresse-invalide',
                  username: 'jean',
                  password: 'secret',
                ),
              )
              .toList(),
          throwsA(isA<NetworkFailure>()),
        );
      });
    });

    test('lit les flux au fil de la réception', () async {
      final firstChunk = Completer<void>();
      final controller = StreamController<List<int>>();
      final client = MockClient.streaming((request, _) async {
        return http.StreamedResponse(controller.stream, 200);
      });
      final api = XtreamApiClient(client, credentials);

      final objects = <Map<String, dynamic>>[];
      final subscription = api.objects('get_live_streams').listen((object) {
        objects.add(object);
        if (!firstChunk.isCompleted) firstChunk.complete();
      });

      controller.add(utf8.encode('[{"stream_id":1},'));
      await firstChunk.future;
      // Le premier objet arrive alors que la réponse n'est pas terminée.
      expect(objects, hasLength(1));

      controller.add(utf8.encode('{"stream_id":2}]'));
      await controller.close();
      await subscription.asFuture<void>();
      await subscription.cancel();
      expect(objects, hasLength(2));
    });
  });
}
