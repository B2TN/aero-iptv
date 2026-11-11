import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../catalog_batch.dart';
import '../playlist_source_adapter.dart';
import 'xtream_api_client.dart';
import 'xtream_entry_mapper.dart';

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
    return [
      SourceSection(
        ContentKind.live,
        () => _section(
          api,
          'get_live_categories',
          'get_live_streams',
          _mapper.live,
        ),
      ),
      SourceSection(
        ContentKind.movie,
        () => _section(
          api,
          'get_vod_categories',
          'get_vod_streams',
          _mapper.movie,
        ),
      ),
      SourceSection(
        ContentKind.series,
        () => _section(
          api,
          'get_series_categories',
          'get_series',
          _mapper.series,
        ),
      ),
    ];
  }

  /// Les catégories font partie de la section : sans elles, ses entrées
  /// n'auraient pas de groupe.
  Stream<CatalogBatch> _section(
    XtreamApiClient api,
    String categoriesAction,
    String listAction,
    CatalogEntry? Function(Map<String, dynamic>, Map<String, String>) map,
  ) async* {
    final categories = await api.categories(categoriesAction);
    yield* _batches(api.objects(listAction), (json) => map(json, categories));
  }

  Stream<CatalogBatch> _batches(
    Stream<Map<String, dynamic>> objects,
    CatalogEntry? Function(Map<String, dynamic>) map,
  ) async* {
    var entries = <CatalogEntry>[];
    await for (final object in objects) {
      final entry = map(object);
      if (entry == null) continue;
      entries.add(entry);
      if (entries.length >= catalogBatchSize) {
        yield CatalogBatch(entries);
        entries = [];
      }
    }
    if (entries.isNotEmpty) yield CatalogBatch(entries);
  }
}
