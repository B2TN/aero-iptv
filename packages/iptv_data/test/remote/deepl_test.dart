import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

http.Response _translated(http.Request request) {
  final texts = (jsonDecode(request.body) as Map)['text'] as List;
  return http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'translations': [
          for (final text in texts) {'text': 'FR:$text'},
        ],
      }),
    ),
    200,
  );
}

void main() {
  test('envoie les répliques à l adresse de la clé gratuite', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return _translated(request);
    });

    final texts = await DeepLSubtitleTranslator(
      client,
      apiKey: 'cle:fx',
    ).translateTexts(['Hello', 'Two\nlines'], language: 'fr');

    expect(texts, ['FR:Hello', 'FR:Two\nlines']);
    expect(sent.url.host, 'api-free.deepl.com');
    expect(sent.headers['Authorization'], 'DeepL-Auth-Key cle:fx');
    expect((jsonDecode(sent.body) as Map)['target_lang'], 'FR');
  });

  test('utilise les codes de langue propres à DeepL', () async {
    final sent = <Object?>[];
    final client = MockClient((request) async {
      sent.add((jsonDecode(request.body) as Map)['target_lang']);
      return _translated(request);
    });
    final translator = DeepLSubtitleTranslator(client, apiKey: 'cle');

    for (final language in const ['en', 'pt', 'no', 'de']) {
      await translator.translateTexts(['Salut'], language: language);
    }

    expect(sent, ['EN-GB', 'PT-PT', 'NB', 'DE']);
  });

  test('traduit des répliques isolées', () async {
    final client = MockClient((request) async => _translated(request));

    final texts = await DeepLSubtitleTranslator(
      client,
      apiKey: 'cle:fx',
    ).translateTexts(['Hello'], language: 'fr');

    expect(texts, ['FR:Hello']);
  });

  test('signale un quota épuisé', () async {
    final client = MockClient((_) async => http.Response('', 456));
    await expectLater(
      DeepLSubtitleTranslator(
        client,
        apiKey: 'cle',
      ).translateTexts(['Hello'], language: 'fr'),
      throwsA(isA<ServerFailure>()),
    );
  });
}
