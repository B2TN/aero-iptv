import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/xtream/xtream_api_client.dart';
import 'epg_source_adapter.dart';
import 'xmltv_epg_adapter.dart';

/// Guide des comptes Xtream, publié au format XMLTV par `xmltv.php`.
///
/// Ce point d'accès évite un appel `get_short_epg` par chaîne.
final class XtreamEpgAdapter implements EpgSourceAdapter {
  const XtreamEpgAdapter(this._client);

  final http.Client _client;

  @override
  Stream<List<EpgProgramme>> fetch(EpgRequest request) {
    final api = XtreamApiClient(
      _client,
      request.credentials as XtreamCredentials,
    );
    return XmltvEpgAdapter(_client).read(api.xmltvUri, request);
  }
}
