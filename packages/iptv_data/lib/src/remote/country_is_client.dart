import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/http_text_stream.dart';

/// Un appel au lancement : un service lent ne doit pas le retarder.
const Duration _timeout = Duration(seconds: 8);

final RegExp _countryCode = RegExp(r'^[A-Za-z]{2}$');

/// Pays de l'adresse IP selon country.is, gratuit, sans clé ni compte.
///
/// Le service voit l'adresse IP ; seul le code du pays est lu et gardé.
final class CountryIsClient implements CountryLocator {
  const CountryIsClient(this._client);

  final http.Client _client;

  @override
  Future<String> country() async {
    final response = await openGet(
      _client,
      Uri.https('api.country.is', '/'),
      timeout: _timeout,
    );
    final Object? json;
    try {
      json = jsonDecode(await textChunks(response).join());
    } on FormatException {
      throw const ParseFailure('Réponse country.is illisible.');
    }
    final code = json is Map<String, dynamic> ? json['country'] : null;
    if (code is! String || !_countryCode.hasMatch(code)) {
      throw const ParseFailure('Pays inconnu de country.is.');
    }
    return code.toUpperCase();
  }
}
