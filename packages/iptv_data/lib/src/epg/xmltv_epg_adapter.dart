import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/http_text_stream.dart';
import 'epg_source_adapter.dart';
import 'xmltv_event_parser.dart';

/// Guide XMLTV des sources M3U.
final class XmltvEpgAdapter implements EpgSourceAdapter {
  const XmltvEpgAdapter(this._client);

  final http.Client _client;

  @override
  Stream<List<EpgProgramme>> fetch(EpgRequest request) {
    final credentials = request.credentials;
    final manualUrl = credentials is M3uCredentials ? credentials.epgUrl : null;
    final url = manualUrl ?? request.discoveredUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    return uri == null ? const Stream.empty() : read(uri, request);
  }

  /// Télécharge un fichier XMLTV et ne garde que les émissions utiles.
  Stream<List<EpgProgramme>> read(Uri uri, EpgRequest request) async* {
    final response = await openGet(
      _client,
      uri,
      timeout: catalogResponseTimeout,
    );
    final matcher = _ChannelMatcher(request.knownKeys);
    var programmes = <EpgProgramme>[];

    await for (final item in parseXmltv(textChunks(response))) {
      switch (item) {
        case XmltvChannel():
          matcher.register(item);
        case XmltvProgramme():
          final key = matcher.keyFor(item.channelId);
          final inWindow =
              item.stop.isAfter(request.from) &&
              item.start.isBefore(request.to);
          if (key == null || !inWindow) continue;
          programmes.add(
            EpgProgramme(
              epgKey: key,
              title: item.title,
              description: item.description,
              start: item.start,
              stop: item.stop,
            ),
          );
          if (programmes.length >= epgBatchSize) {
            yield programmes;
            programmes = [];
          }
      }
    }
    if (programmes.isNotEmpty) yield programmes;
  }
}

/// Relie les chaînes du guide à celles du catalogue.
///
/// L'identifiant `tvg-id` est essayé en premier. Le nom affiché sert de repli,
/// car de nombreuses playlists ne renseignent pas cet identifiant.
final class _ChannelMatcher {
  _ChannelMatcher(this._knownKeys);

  final Set<String> _knownKeys;
  final Map<String, String> _aliases = {};
  final TitleCleaner _cleaner = const TitleCleaner();

  void register(XmltvChannel channel) {
    final id = channel.id.toLowerCase();
    if (_knownKeys.contains(id)) return;
    for (final name in channel.displayNames) {
      final key = GroupingKey.of(_cleaner.parse(name, ContentKind.live).title);
      if (_knownKeys.contains(key)) {
        _aliases[id] = key;
        return;
      }
    }
  }

  String? keyFor(String channelId) {
    final id = channelId.toLowerCase();
    return _knownKeys.contains(id) ? id : _aliases[id];
  }
}
