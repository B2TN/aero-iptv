import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

/// Identité envoyée par défaut par le lecteur : la réponse doit être la sienne.
const String _playerUserAgent = 'libmpv';
const Duration _timeout = Duration(seconds: 10);
const int _maxRedirects = 5;

/// Suit les redirections d'un flux, jusqu'à la réponse finale.
///
/// Seuls les en-têtes sont lus. Le client est fermé aussitôt : un compte n'a
/// parfois droit qu'à une connexion, et celle-ci ne doit pas la lui prendre.
final class HttpStreamProbe implements StreamProbe {
  const HttpStreamProbe({http.Client Function() client = http.Client.new})
    : _client = client;

  final http.Client Function() _client;

  @override
  Future<StreamProbeResult?> probe(ResolvedStream stream) async {
    var url = Uri.tryParse(stream.url);
    if (url == null || !url.isScheme('http') && !url.isScheme('https')) {
      return null;
    }
    final origin = url.host;
    final client = _client();
    try {
      for (var hop = 0; hop <= _maxRedirects; hop++) {
        final request = http.Request('GET', url!)
          ..followRedirects = false
          ..headers['User-Agent'] = _playerUserAgent
          ..headers.addAll(stream.headers);
        final response = await client.send(request).timeout(_timeout);
        final location = response.headers['location'];
        if (response.isRedirect && location != null) {
          url = url.resolve(location);
          continue;
        }
        final type = response.headers['content-type'];
        return StreamProbeResult(
          status: response.statusCode,
          redirectedTo: url.host == origin ? null : url.host,
          isVideo: type == null ? null : !type.startsWith('text/html'),
        );
      }
      return const StreamProbeResult();
    } on TimeoutException {
      return const StreamProbeResult();
    } on http.ClientException {
      return const StreamProbeResult();
    } on SocketException {
      return const StreamProbeResult();
    } finally {
      client.close();
    }
  }
}
