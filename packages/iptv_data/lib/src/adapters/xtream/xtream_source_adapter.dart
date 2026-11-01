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
  Stream<CatalogBatch> fetch(PlaylistCredentials credentials) async* {
    final api = XtreamApiClient(_client, credentials as XtreamCredentials);
    await api.authenticate();

    final liveCategories = await api.categories('get_live_categories');
    yield* _batches(
      api.objects('get_live_streams'),
      (json) => _mapper.live(json, liveCategories),
    );

    final movieCategories = await api.categories('get_vod_categories');
    yield* _batches(
      api.objects('get_vod_streams'),
      (json) => _mapper.movie(json, movieCategories),
    );

    final seriesCategories = await api.categories('get_series_categories');
    yield* _batches(
      api.objects('get_series'),
      (json) => _mapper.series(json, seriesCategories),
    );
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
