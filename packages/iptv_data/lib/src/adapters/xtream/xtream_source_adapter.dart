import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import 'dart:convert';

import '../catalog_batch.dart';
import '../playlist_source_adapter.dart';
import 'raw_entry.dart';
import 'xtream_api_client.dart';
import 'xtream_entry_mapper.dart';

/// Objets reçus sans rien livrer au-delà desquels un lot vide part quand
/// même : l'avancement de la synchronisation reste à jour.
const int _receivedPerBatch = catalogBatchSize * 8;

/// Section d'une liste Xtream : ses actions et le champ qui identifie ses
/// objets.
typedef _List = ({
  ContentKind kind,
  String categories,
  String list,
  String idField,
  String identity,
  Set<String> hashed,
  CatalogEntry? Function(Map<String, dynamic>, Map<String, String>, int?, int?)
  map,
});

/// Adapter de l'API Xtream Codes.
///
/// Les épisodes ne sont pas importés ici : un appel par série rendrait la
/// synchronisation interminable. Ils sont chargés à l'ouverture d'une série.
final class XtreamSourceAdapter implements PlaylistSourceAdapter {
  const XtreamSourceAdapter(
    this._client, {
    XtreamEntryMapper mapper = const XtreamEntryMapper(),
  }) : _mapper = mapper;

  final http.Client _client;
  final XtreamEntryMapper _mapper;

  @override
  Future<List<SourceSection>> open(PlaylistCredentials credentials) async {
    final api = XtreamApiClient(_client, credentials as XtreamCredentials);
    await api.authenticate();
    final List<_List> lists = [
      (
        kind: ContentKind.live,
        categories: 'get_live_categories',
        list: 'get_live_streams',
        idField: 'stream_id',
        identity: 'x:l:',
        hashed: const {
          'name',
          'stream_id',
          'stream_icon',
          'epg_channel_id',
          'category_id',
        },
        map: _mapper.live,
      ),
      (
        kind: ContentKind.movie,
        categories: 'get_vod_categories',
        list: 'get_vod_streams',
        idField: 'stream_id',
        identity: 'x:m:',
        hashed: const {
          'name',
          'stream_id',
          'stream_icon',
          'tmdb',
          'tmdb_id',
          'container_extension',
          'category_id',
        },
        map: _mapper.movie,
      ),
      (
        kind: ContentKind.series,
        categories: 'get_series_categories',
        list: 'get_series',
        idField: 'series_id',
        identity: 'x:s:',
        hashed: const {
          'name',
          'series_id',
          'cover',
          'tmdb',
          'tmdb_id',
          'last_modified',
          'category_id',
        },
        map: _mapper.series,
      ),
    ];
    return [
      for (final list in lists)
        SourceSection(
          list.kind,
          () => _section(api, list, null),
          fetchChanges: (gate) => _section(api, list, gate),
        ),
    ];
  }

  /// Les catégories font partie de la section : sans elles, ses entrées
  /// n'auraient pas de groupe.
  ///
  /// Chaque objet garde l'empreinte des champs que l'application en lit. Avec
  /// une [gate], un objet qu'elle refuse n'est même pas décodé.
  Stream<CatalogBatch> _section(
    XtreamApiClient api,
    _List list,
    EntryGate? gate,
  ) async* {
    final categories = await api.categories(list.categories);
    final groups = categoriesHash(categories);
    var entries = <CatalogEntry>[];
    var received = 0;
    var position = 0;
    await for (final raw in api.rawObjects(list.list)) {
      received++;
      position++;
      final hash = rawFieldsHash(raw, list.hashed, groups);
      final id = rawEntryId(raw, list.idField);
      if (gate == null ||
          id == null ||
          gate('${list.identity}$id', hash, () => rawEntryHash(raw, groups))) {
        final Object? json;
        try {
          json = jsonDecode(raw);
        } on FormatException {
          throw const ParseFailure('Réponse Xtream illisible.');
        }
        final entry = json is Map<String, dynamic>
            ? list.map(json, categories, hash, position)
            : null;
        if (entry != null) entries.add(entry);
      }
      if (entries.length >= catalogBatchSize || received >= _receivedPerBatch) {
        yield CatalogBatch(entries, received: received);
        entries = [];
        received = 0;
      }
    }
    if (entries.isNotEmpty || received > 0) {
      yield CatalogBatch(entries, received: received);
    }
  }
}
