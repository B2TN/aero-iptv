import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../catalog_batch.dart';
import '../http_text_stream.dart';
import '../playlist_source_adapter.dart';
import 'm3u_entry_mapper.dart';
import 'm3u_line_parser.dart';

/// Adapter des playlists M3U.
final class M3uSourceAdapter implements PlaylistSourceAdapter {
  const M3uSourceAdapter(
    this._client, {
    M3uEntryMapper mapper = const M3uEntryMapper(),
  }) : _mapper = mapper;

  final http.Client _client;
  final M3uEntryMapper _mapper;

  @override
  Stream<CatalogBatch> fetch(PlaylistCredentials credentials) async* {
    final uri = Uri.tryParse((credentials as M3uCredentials).playlistUrl);
    if (uri == null || !uri.hasScheme) {
      throw const ParseFailure('Adresse de playlist invalide.');
    }

    final response = await openGet(
      _client,
      uri,
      timeout: catalogResponseTimeout,
    );
    final parser = M3uLineParser();
    var entries = <CatalogEntry>[];

    await for (final line in textChunks(
      response,
    ).transform(const LineSplitter())) {
      final entry = parser.accept(line);
      final mapped = entry == null ? null : _mapper.map(entry);
      if (mapped == null) continue;
      entries.add(mapped);
      if (entries.length >= catalogBatchSize) {
        yield CatalogBatch(entries, discoveredEpgUrl: parser.epgUrl);
        entries = [];
      }
    }

    if (!parser.sawPlaylistContent) {
      throw const ParseFailure("La réponse n'est pas une playlist M3U.");
    }
    if (entries.isNotEmpty) {
      yield CatalogBatch(entries, discoveredEpgUrl: parser.epgUrl);
    }
  }
}
