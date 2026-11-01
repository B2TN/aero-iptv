import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

const SubtitleFile _english = SubtitleFile(
  content:
      '1\n00:00:01,000 --> 00:00:02,000\nHello\n\n'
      '2\n00:00:03,000 --> 00:00:04,000\nTwo\nlines\n',
  language: 'en',
  title: 'Dexter',
);

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
  test('traduit le texte sans toucher aux temps', () async {
    late http.Request sent;
    final client = MockClient((request) async {
      sent = request;
      return _translated(request);
    });

    final file = await DeepLSubtitleTranslator(
      client,
      apiKey: 'cle:fx',
    ).translate(_english, language: 'fr');

    expect(file.language, 'fr');
    expect(
      file.content,
      '1\n00:00:01,000 --> 00:00:02,000\nFR:Hello\n\n'
      '2\n00:00:03,000 --> 00:00:04,000\nFR:Two\nlines\n',
    );
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

  test('envoie un long fichier par lots', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return _translated(request);
    });
    final content = [
      for (var index = 1; index <= 120; index++)
        '$index\n00:00:01,000 --> 00:00:02,000\nLigne $index',
    ].join('\n\n');

    final file = await DeepLSubtitleTranslator(client, apiKey: 'cle').translate(
      SubtitleFile(content: content, language: 'en', title: 'Long'),
      language: 'de',
    );

    expect(calls, 3);
    expect(file.content, contains('FR:Ligne 120'));
  });

  test('signale un quota épuisé', () async {
    final client = MockClient((_) async => http.Response('', 456));
    await expectLater(
      DeepLSubtitleTranslator(
        client,
        apiKey: 'cle',
      ).translate(_english, language: 'fr'),
      throwsA(isA<ServerFailure>()),
    );
  });
}
