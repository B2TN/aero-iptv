import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

void main() {
  test('lit seulement le code du pays', () async {
    late Uri asked;
    final client = MockClient((request) async {
      asked = request.url;
      return http.Response(
        jsonEncode({'ip': '192.0.2.1', 'country': 'fr'}),
        200,
      );
    });

    expect(await CountryIsClient(client).country(), 'FR');
    expect(asked.toString(), 'https://api.country.is/');
  });

  test('rejette une réponse sans pays', () {
    final client = MockClient(
      (_) async => http.Response(jsonEncode({'ip': '192.0.2.1'}), 200),
    );

    expect(CountryIsClient(client).country(), throwsA(isA<ParseFailure>()));
  });

  test('signale un service muet', () {
    final client = MockClient((_) async => http.Response('', 503));

    expect(CountryIsClient(client).country(), throwsA(isA<ServerFailure>()));
  });
}
