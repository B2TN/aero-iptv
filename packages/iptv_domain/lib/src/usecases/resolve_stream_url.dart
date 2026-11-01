import '../common/failure.dart';
import '../entities/playlist_source.dart';
import '../entities/stream_locator.dart';
import '../ports/credential_store.dart';

/// Construit l'URL d'un flux juste avant sa lecture.
final class ResolveStreamUrl {
  const ResolveStreamUrl(this._credentials);

  final CredentialStore _credentials;

  Future<ResolvedStream> call(int sourceId, StreamLocator locator) async {
    switch (locator) {
      case DirectStream():
        return ResolvedStream(
          url: locator.url,
          headers: {
            'User-Agent': ?locator.userAgent,
            'Referer': ?locator.referrer,
          },
        );
      case XtreamStream():
        final credentials = await _credentials.read(sourceId);
        if (credentials is! XtreamCredentials) {
          throw const AuthFailure('Compte Xtream absent du coffre.');
        }
        return ResolvedStream(url: buildXtreamUrl(credentials, locator));
    }
  }

  /// Applique le schéma Xtream `/{espace}/{compte}/{mot de passe}/{id}.{ext}`.
  static String buildXtreamUrl(
    XtreamCredentials credentials,
    XtreamStream stream,
  ) {
    final server = normalizeXtreamServer(credentials.serverUrl);
    final user = Uri.encodeComponent(credentials.username);
    final password = Uri.encodeComponent(credentials.password);
    return '$server/${stream.namespace.path}/$user/$password/'
        '${stream.streamId}.${stream.extension}';
  }

  /// Accepte une adresse sans schéma, copiée avec son chemin d'API, ou suivie
  /// d'autres adresses du fournisseur : seule la première est retenue.
  static String normalizeXtreamServer(String input) {
    final first = RegExp(r'[^\s;,]+').firstMatch(input)?.group(0) ?? '';
    final uri = Uri.parse(first.contains('://') ? first : 'http://$first');
    final path = uri.path
        .replaceFirst(RegExp(r'/(?:player_api|get|xmltv)\.php$'), '')
        .replaceFirst(RegExp(r'/+$'), '');
    return '${uri.scheme}://${uri.authority}$path';
  }
}
