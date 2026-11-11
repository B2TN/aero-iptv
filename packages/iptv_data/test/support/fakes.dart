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

/// Adapter d'un seul tenant, qui émet des lots prédéfinis, puis échoue si
/// [failure] est renseigné.
final class FakeCatalogAdapter implements PlaylistSourceAdapter {
  const FakeCatalogAdapter(this.batches, {this.failure});

  final List<CatalogBatch> batches;
  final Failure? failure;

  @override
  Future<List<SourceSection>> open(PlaylistCredentials credentials) async => [
    SourceSection(null, _fetch),
  ];

  Stream<CatalogBatch> _fetch() async* {
    yield* Stream.fromIterable(batches);
    final error = failure;
    if (error != null) throw error;
  }
}

/// Résultat d'un essai de téléchargement : des lots, puis une panne éventuelle.
typedef Attempt = ({List<CatalogBatch> batches, Failure? failure});

Attempt succeeds(List<CatalogEntry> entries) =>
    (batches: [CatalogBatch(entries)], failure: null);

Attempt fails(Failure failure, {List<CatalogEntry> after = const []}) =>
    (batches: [if (after.isNotEmpty) CatalogBatch(after)], failure: failure);

/// Adapter à sections, dont chaque essai est décidé d'avance. Le dernier essai
/// décrit se répète.
final class SectionedCatalogAdapter implements PlaylistSourceAdapter {
  SectionedCatalogAdapter(this.attempts);

  final Map<ContentKind, List<Attempt>> attempts;

  /// Nombre d'essais demandés pour chaque section.
  final Map<ContentKind, int> calls = {};

  @override
  Future<List<SourceSection>> open(PlaylistCredentials credentials) async => [
    for (final kind in attempts.keys) SourceSection(kind, () => _fetch(kind)),
  ];

  Stream<CatalogBatch> _fetch(ContentKind kind) async* {
    final planned = attempts[kind]!;
    final call = calls.update(kind, (count) => count + 1, ifAbsent: () => 1);
    final attempt =
        planned[call > planned.length ? planned.length - 1 : call - 1];
    yield* Stream.fromIterable(attempt.batches);
    final error = attempt.failure;
    if (error != null) throw error;
  }
}

MovieEntry movie(String name, {String group = 'VOD', int id = 1}) => MovieEntry(
  rawName: name,
  rawGroup: group,
  locator: DirectStream('http://s/movie/$id.mkv'),
);

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
