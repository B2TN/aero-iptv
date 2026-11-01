import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart';
import '../remote/opensubtitles_client.dart';

/// Sous-titres conservés, soit quelques Mio au plus.
const int _cachedSubtitles = 50;

/// Sous-titres OpenSubtitles, conservés en base.
///
/// Le quota de téléchargement est limité par jour : reprendre un film ne doit
/// pas le consommer une seconde fois.
final class SubtitleRepositoryImpl implements SubtitleRepository {
  /// [client] est `null` tant qu'aucune clé d'API n'est configurée.
  const SubtitleRepositoryImpl(
    this._db,
    this._client, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final OpenSubtitlesClient? _client;
  final DateTime Function() _clock;

  @override
  bool get isAvailable => _client != null;

  @override
  Future<SubtitleFile?> find(SubtitleQuery query) async {
    final cached = await _db
        .cachedSubtitle(contentKey: query.contentKey, language: query.language)
        .getSingleOrNull();
    if (cached != null) {
      return SubtitleFile(
        content: cached.content,
        language: cached.language,
        title: cached.title,
      );
    }

    final client = _client;
    if (client == null) return null;
    final fileId = await client.findBestFileId(query);
    if (fileId == null) return null;
    final file = SubtitleFile(
      content: await client.download(fileId),
      language: query.language,
      title: query.title,
    );
    await remember(query, file);
    return file;
  }

  @override
  Future<void> remember(SubtitleQuery query, SubtitleFile file) async {
    await _db
        .into(_db.subtitleCache)
        .insertOnConflictUpdate(
          SubtitleCacheCompanion.insert(
            contentKey: query.contentKey,
            language: query.language,
            title: file.title,
            content: file.content,
            createdAt: _clock().millisecondsSinceEpoch,
          ),
        );
    await _db.trimSubtitleCache(keep: _cachedSubtitles);
  }
}
