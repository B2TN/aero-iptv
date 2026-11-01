import 'package:iptv_domain/iptv_domain.dart';

import '../catalog_batch.dart';
import 'm3u_line_parser.dart';

/// Extensions typiques d'un fichier de VOD.
final RegExp _vodExtension = RegExp(
  r'\.(?:mkv|mp4|avi|mov|wmv|flv|webm)(?:\?|$)',
  caseSensitive: false,
);

/// Chemins des playlists générées par un panneau Xtream.
final RegExp _moviePath = RegExp(r'/movies?/');
final RegExp _seriesPath = RegExp(r'/series/');
final RegExp _livePath = RegExp(r'/live/');

/// Traduit une entrée M3U vers le format commun.
final class M3uEntryMapper {
  const M3uEntryMapper({TitleCleaner cleaner = const TitleCleaner()})
    : _cleaner = cleaner;

  final TitleCleaner _cleaner;

  /// Retourne `null` pour une ligne de séparation déguisée en chaîne.
  CatalogEntry? map(M3uEntry entry) {
    final name = entry.title.isNotEmpty
        ? entry.title
        : entry.attributes['tvg-name'] ?? '';
    if (name.isEmpty || _cleaner.isHeaderEntry(name)) return null;

    final group = entry.group ?? '';
    final logo = entry.attributes['tvg-logo'];
    final logoUrl = logo == null || logo.isEmpty ? null : logo;
    final locator = DirectStream(
      entry.url,
      userAgent: entry.userAgent,
      referrer: entry.referrer,
    );

    return switch (_classify(entry.url, name)) {
      ContentKind.live => LiveEntry(
        rawName: name,
        rawGroup: group,
        locator: locator,
        logoUrl: logoUrl,
        tvgId: _nonEmpty(entry.attributes['tvg-id']),
        tvgCountry: _nonEmpty(entry.attributes['tvg-country']),
      ),
      ContentKind.movie => MovieEntry(
        rawName: name,
        rawGroup: group,
        locator: locator,
        logoUrl: logoUrl,
      ),
      ContentKind.series => EpisodeEntry(
        rawName: name,
        rawGroup: group,
        locator: locator,
        logoUrl: logoUrl,
      ),
    };
  }

  /// Le chemin de l'URL est l'indice le plus fiable. Viennent ensuite le
  /// marqueur d'épisode dans le nom, puis l'extension du fichier.
  ContentKind _classify(String url, String name) {
    if (_seriesPath.hasMatch(url)) return ContentKind.series;
    if (_moviePath.hasMatch(url)) return ContentKind.movie;
    if (_livePath.hasMatch(url)) return ContentKind.live;
    final isVodFile = _vodExtension.hasMatch(url);
    if (isVodFile && _cleaner.hasEpisodeMarker(name)) return ContentKind.series;
    return isVodFile ? ContentKind.movie : ContentKind.live;
  }

  String? _nonEmpty(String? value) =>
      value == null || value.isEmpty ? null : value;
}
