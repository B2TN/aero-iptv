import 'package:drift/drift.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart';

/// Favoris, gardés hors du catalogue : une synchronisation ne les touche pas.
final class FavoritesRepositoryImpl implements FavoritesRepository {
  const FavoritesRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Favorite>> watch(int sourceId) =>
      (_db.select(_db.favorites)
            ..where((row) => row.sourceId.equals(sourceId))
            ..orderBy([(row) => OrderingTerm.desc(row.addedAt)]))
          .watch()
          .map(
            (rows) => [
              for (final row in rows)
                Favorite(
                  sourceId: row.sourceId,
                  kind: ContentKind.values[row.kind],
                  key: row.favoriteKey,
                  title: row.title,
                  posterUrl: row.posterUrl,
                  addedAt: DateTime.fromMillisecondsSinceEpoch(row.addedAt),
                ),
            ],
          );

  @override
  Future<void> add(Favorite favorite) async {
    await _db
        .into(_db.favorites)
        .insertOnConflictUpdate(
          FavoritesCompanion.insert(
            sourceId: favorite.sourceId,
            kind: favorite.kind.index,
            favoriteKey: favorite.key,
            title: favorite.title,
            posterUrl: Value(favorite.posterUrl),
            addedAt: favorite.addedAt.millisecondsSinceEpoch,
          ),
        );
    // Le témoin qui fera suivre au favori sa fiche, si elle change.
    await _db.refreshUserKeys();
  }

  @override
  Future<void> remove(int sourceId, ContentKind kind, String key) =>
      (_db.delete(_db.favorites)..where(
            (row) =>
                row.sourceId.equals(sourceId) &
                row.kind.equals(kind.index) &
                row.favoriteKey.equals(key),
          ))
          .go();
}
