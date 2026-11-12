import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

/// Identité envoyée à tous les serveurs.
const String appUserAgent = 'AeroIPTV/0.1';

const Duration _responseTimeout = Duration(seconds: 30);
const Duration _idleTimeout = Duration(seconds: 60);

/// Attente d'une playlist, d'un guide ou d'un catalogue : les serveurs les
/// génèrent souvent en entier avant d'envoyer la première réponse.
const Duration catalogResponseTimeout = Duration(minutes: 2);

/// Ouvre une requête GET en flux.
Future<http.StreamedResponse> openGet(
  http.Client client,
  Uri uri, {
  Map<String, String> headers = const {},
  Duration timeout = _responseTimeout,
}) => sendRequest(
  client,
  http.Request('GET', uri)
    ..headers['User-Agent'] = appUserAgent
    ..headers.addAll(headers),
  timeout: timeout,
);

/// Envoie [request] et vérifie le statut de la réponse.
///
/// Les erreurs sont converties en [Failure] sans reprendre l'URL, car elle
/// contient les identifiants de l'abonné.
Future<http.StreamedResponse> sendRequest(
  http.Client client,
  http.BaseRequest request, {
  Duration timeout = _responseTimeout,
}) async {
  try {
    final response = await client.send(request).timeout(timeout);
    final status = response.statusCode;
    if (status == 401 || status == 403) {
      await response.stream.drain<void>();
      throw AuthFailure(
        'Accès refusé par le serveur (HTTP $status).',
        status: status,
      );
    }
    if (status == 406 || status == 429) {
      await response.stream.drain<void>();
      throw RateLimitFailure('Quota du service atteint (HTTP $status).');
    }
    if (status < 200 || status >= 300) {
      await response.stream.drain<void>();
      throw ServerFailure('Réponse inattendue (HTTP $status).', status: status);
    }
    return response;
  } on TimeoutException {
    throw const NetworkFailure('Le serveur ne répond pas.');
  } on http.ClientException {
    throw const NetworkFailure('Connexion impossible.');
  } on SocketException {
    throw const NetworkFailure('Connexion impossible.');
  } on TlsException {
    // Le paquet http ne convertit pas cette erreur-ci.
    throw const SecureConnectionFailure('Connexion chiffrée refusée.');
  }
}

/// Corps de [response], décompressé et décodé au fil de l'eau.
Stream<String> textChunks(http.StreamedResponse response) {
  final guarded = response.stream
      .timeout(_idleTimeout)
      .handleError(_rethrowAsFailure);
  return const Utf8Decoder(allowMalformed: true).bind(_gunzipIfNeeded(guarded));
}

Never _rethrowAsFailure(Object error) => throw switch (error) {
  TimeoutException() => const NetworkFailure('Téléchargement interrompu.'),
  http.ClientException() ||
  SocketException() ||
  HttpException() ||
  TlsException() => const NetworkFailure('Téléchargement interrompu.'),
  _ => error,
};

/// Détecte le format gzip par sa signature : les guides XMLTV sont souvent
/// servis en `.xml.gz` sans en-tête `Content-Encoding`.
Stream<List<int>> _gunzipIfNeeded(Stream<List<int>> source) async* {
  final iterator = StreamIterator(source);
  try {
    if (!await iterator.moveNext()) return;
    final first = iterator.current;
    final isGzip = first.length >= 2 && first[0] == 0x1f && first[1] == 0x8b;

    Stream<List<int>> remaining() async* {
      yield first;
      while (await iterator.moveNext()) {
        yield iterator.current;
      }
    }

    yield* isGzip ? gzip.decoder.bind(remaining()) : remaining();
  } finally {
    await iterator.cancel();
  }
}
