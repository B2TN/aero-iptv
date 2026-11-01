import 'package:iptv_data/src/adapters/catalog_batch.dart';
import 'package:iptv_data/src/adapters/playlist_source_adapter.dart';
import 'package:iptv_data/src/epg/epg_source_adapter.dart';
import 'package:iptv_domain/iptv_domain.dart';

/// Coffre en mémoire.
final class MemoryCredentialStore implements CredentialStore {
  final Map<int, PlaylistCredentials> values = {};

  @override
  Future<PlaylistCredentials?> read(int sourceId) async => values[sourceId];

  @override
  Future<void> write(int sourceId, PlaylistCredentials credentials) async {
    values[sourceId] = credentials;
  }

  @override
  Future<void> delete(int sourceId) async {
    values.remove(sourceId);
  }
}

/// Adapter qui émet des lots prédéfinis, puis échoue si [failure] est renseigné.
final class FakeCatalogAdapter implements PlaylistSourceAdapter {
  const FakeCatalogAdapter(this.batches, {this.failure});

  final List<CatalogBatch> batches;
  final Failure? failure;

  @override
  Stream<CatalogBatch> fetch(PlaylistCredentials credentials) async* {
    yield* Stream.fromIterable(batches);
    final error = failure;
    if (error != null) throw error;
  }
}

/// Guide prédéfini.
final class FakeEpgAdapter implements EpgSourceAdapter {
  const FakeEpgAdapter({this.programmes = const [], this.failure});

  final List<EpgProgramme> programmes;
  final Failure? failure;

  @override
  Stream<List<EpgProgramme>> fetch(EpgRequest request) async* {
    final error = failure;
    if (error != null) throw error;
    if (programmes.isNotEmpty) yield programmes;
  }
}

LiveEntry live(String name, String group, {String? tvgId, int id = 1}) =>
    LiveEntry(
      rawName: name,
      rawGroup: group,
      tvgId: tvgId,
      locator: DirectStream('http://s/live/$id.ts'),
    );
