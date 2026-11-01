import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart';
import '../database/daos/catalog_maintenance_dao.dart';

/// Gestionnaire des sources. Les identifiants restent dans le coffre.
final class PlaylistRepositoryImpl implements PlaylistRepository {
  PlaylistRepositoryImpl(this._db, this._credentials)
    : _maintenance = CatalogMaintenanceDao(_db);

  final AppDatabase _db;
  final CredentialStore _credentials;
  final CatalogMaintenanceDao _maintenance;

  @override
  Stream<List<PlaylistSource>> watchSources() =>
      (_db.select(_db.sources)
            ..orderBy([(row) => OrderingTerm(expression: row.id)]))
          .watch()
          .map((rows) => rows.map(_toSource).toList(growable: false));

  @override
  Future<Result<PlaylistSource>> add({
    required String name,
    required PlaylistCredentials credentials,
    String? defaultCountryCode,
  }) async {
    final id = await _db
        .into(_db.sources)
        .insert(
          SourcesCompanion.insert(
            name: name,
            kind: credentials.kind.index,
            defaultCountryCode: Value(defaultCountryCode),
          ),
        );
    await _credentials.write(id, credentials);
    return Ok(
      PlaylistSource(
        id: id,
        name: name,
        kind: credentials.kind,
        defaultCountryCode: defaultCountryCode,
      ),
    );
  }

  @override
  Future<Result<void>> update(
    PlaylistSource source, {
    PlaylistCredentials? credentials,
  }) async {
    final updated =
        await (_db.update(
          _db.sources,
        )..where((row) => row.id.equals(source.id))).write(
          SourcesCompanion(
            name: Value(source.name),
            defaultCountryCode: Value(source.defaultCountryCode),
          ),
        );
    if (updated == 0) {
      return const Err(NotFoundFailure('Source introuvable.'));
    }
    if (credentials != null) await _credentials.write(source.id, credentials);
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(int sourceId) async {
    await _maintenance.purgeSource(sourceId);
    await (_db.delete(
      _db.sources,
    )..where((row) => row.id.equals(sourceId))).go();
    await _credentials.delete(sourceId);
    return const Ok(null);
  }

  PlaylistSource _toSource(SourceRow row) {
    final syncedAt = row.lastSyncedAt;
    return PlaylistSource(
      id: row.id,
      name: row.name,
      kind: SourceKind.values[row.kind],
      defaultCountryCode: row.defaultCountryCode,
      lastSyncedAt: syncedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(syncedAt),
    );
  }
}
