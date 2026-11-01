import 'package:iptv_domain/iptv_domain.dart';

import '../catalog_batch.dart';
import 'xtream_dtos.dart';

/// Format de sortie des chaînes en direct.
const String _liveContainer = 'ts';
const String _defaultVodContainer = 'mp4';

/// Traduit les objets JSON Xtream vers le format commun.
///
/// Chaque méthode retourne `null` si l'objet n'a ni nom ni identifiant.
final class XtreamEntryMapper {
  const XtreamEntryMapper();

  LiveEntry? live(Map<String, dynamic> json, Map<String, String> categories) {
    final id = readInt(json['stream_id']);
    final name = readString(json['name']);
    if (id == null || name == null) return null;
    return LiveEntry(
      rawName: name,
      rawGroup: _category(json, categories),
      logoUrl: readString(json['stream_icon']),
      tvgId: readString(json['epg_channel_id']),
      locator: XtreamStream(
        namespace: XtreamNamespace.live,
        streamId: id,
        extension: _liveContainer,
      ),
    );
  }

  MovieEntry? movie(Map<String, dynamic> json, Map<String, String> categories) {
    final id = readInt(json['stream_id']);
    final name = readString(json['name']);
    if (id == null || name == null) return null;
    return MovieEntry(
      rawName: name,
      rawGroup: _category(json, categories),
      logoUrl: readString(json['stream_icon']),
      locator: XtreamStream(
        namespace: XtreamNamespace.movie,
        streamId: id,
        extension:
            readString(json['container_extension']) ?? _defaultVodContainer,
      ),
    );
  }

  SeriesEntry? series(
    Map<String, dynamic> json,
    Map<String, String> categories,
  ) {
    final id = readInt(json['series_id']);
    final name = readString(json['name']);
    if (id == null || name == null) return null;
    return SeriesEntry(
      rawName: name,
      rawGroup: _category(json, categories),
      logoUrl: readString(json['cover']),
      xtreamSeriesId: id,
      tmdbId: readString(json['tmdb']) ?? readString(json['tmdb_id']),
    );
  }

  String _category(Map<String, dynamic> json, Map<String, String> categories) =>
      categories[readString(json['category_id'])] ?? '';
}
