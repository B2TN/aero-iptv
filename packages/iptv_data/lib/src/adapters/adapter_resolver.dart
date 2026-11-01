import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../epg/epg_source_adapter.dart';
import '../epg/xmltv_epg_adapter.dart';
import '../epg/xtream_epg_adapter.dart';
import 'm3u/m3u_source_adapter.dart';
import 'playlist_source_adapter.dart';
import 'xtream/xtream_source_adapter.dart';

/// Associe chaque format de source à ses adapters.
///
/// C'est le seul endroit à modifier pour ajouter un format.
final class AdapterResolver {
  const AdapterResolver(this._client);

  final http.Client _client;

  PlaylistSourceAdapter catalogFor(PlaylistCredentials credentials) =>
      switch (credentials) {
        M3uCredentials() => M3uSourceAdapter(_client),
        XtreamCredentials() => XtreamSourceAdapter(_client),
      };

  EpgSourceAdapter epgFor(PlaylistCredentials credentials) =>
      switch (credentials) {
        M3uCredentials() => XmltvEpgAdapter(_client),
        XtreamCredentials() => XtreamEpgAdapter(_client),
      };
}
