import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/iptv_player.dart';

import 'infrastructure_providers.dart';

/// Seul fichier de l'application qui connaît les implémentations : les écrans
/// ne manipulent que les ports du domaine.
const String _tmdbToken = String.fromEnvironment('TMDB_READ_TOKEN');
const String _openSubtitlesKey = String.fromEnvironment(
  'OPENSUBTITLES_API_KEY',
);
const String _deepLKey = String.fromEnvironment('DEEPL_API_KEY');

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => PlaylistRepositoryImpl(
    ref.watch(databaseProvider),
    ref.watch(credentialStoreProvider),
  ),
);

final liveTvRepositoryProvider = Provider<LiveTvRepository>(
  (ref) => LiveTvRepositoryImpl(ref.watch(databaseProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(
    ref.watch(databaseProvider),
    ref.watch(credentialStoreProvider),
    ref.watch(httpClientProvider),
  ),
);

final epgRepositoryProvider = Provider<EpgRepository>(
  (ref) => EpgRepositoryImpl(ref.watch(databaseProvider)),
);

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepositoryImpl(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(ref.watch(databaseProvider)),
);

final watchProgressRepositoryProvider = Provider<WatchProgressRepository>(
  (ref) => WatchProgressRepositoryImpl(ref.watch(databaseProvider)),
);

final streamProbeProvider = Provider<StreamProbe>(
  (ref) => const HttpStreamProbe(),
);

/// Clé d'API saisie dans les paramètres, qui prime sur celle de la compilation.
class ApiKeyController extends Notifier<String?> {
  ApiKeyController(this._name, this._compiled);

  final String _name;
  final String _compiled;

  @override
  String? build() {
    unawaited(_load());
    return _compiled.isEmpty ? null : _compiled;
  }

  /// Une clé illisible, par exemple après un changement de compte Windows,
  /// revient à ne pas en avoir : les paramètres permettent de la ressaisir.
  Future<void> _load() async {
    try {
      final saved = await ref.read(apiKeyStoreProvider).read(_name);
      if (saved != null) state = saved;
    } on Failure {
      return;
    }
  }

  /// [key] à `null` efface la clé.
  Future<void> save(String? key) async {
    await ref.read(apiKeyStoreProvider).write(_name, key);
    state = key ?? (_compiled.isEmpty ? null : _compiled);
  }
}

final deepLKeyProvider = NotifierProvider<ApiKeyController, String?>(
  () => ApiKeyController('deepl', _deepLKey),
);

final openSubtitlesKeyProvider = NotifierProvider<ApiKeyController, String?>(
  () => ApiKeyController('opensubtitles', _openSubtitlesKey),
);

final subtitleRepositoryProvider = Provider<SubtitleRepository>((ref) {
  final key = ref.watch(openSubtitlesKeyProvider);
  return SubtitleRepositoryImpl(
    ref.watch(databaseProvider),
    key == null
        ? null
        : OpenSubtitlesClient(ref.watch(httpClientProvider), apiKey: key),
  );
});

/// `null` tant qu'aucune clé de traduction n'est configurée.
final subtitleTranslatorProvider = Provider<SubtitleTranslator?>((ref) {
  final key = ref.watch(deepLKeyProvider);
  return key == null
      ? null
      : DeepLSubtitleTranslator(ref.watch(httpClientProvider), apiKey: key);
});

/// Gardé pour toute la session : ses réponses en mémoire servent à tous les
/// épisodes d'une série.
final segmentRepositoryProvider = Provider<SegmentRepository>((ref) {
  final client = ref.watch(httpClientProvider);
  return SegmentRepositoryImpl(
    theIntroDb: TheIntroDbClient(client),
    introDb: IntroDbClient(client),
    tvMaze: TvMazeClient(client),
  );
});

final findMediaSegmentsProvider = Provider<FindMediaSegments>(
  (ref) => FindMediaSegments(ref.watch(segmentRepositoryProvider)),
);

final trendingRepositoryProvider = Provider<TrendingRepository>(
  (ref) => TrendingRepositoryImpl(
    _tmdbToken.isEmpty
        ? null
        : TmdbClient(ref.watch(httpClientProvider), readToken: _tmdbToken),
    charts: AppleChartsClient(ref.watch(httpClientProvider)),
  ),
);

final catalogImporterProvider = Provider<CatalogImporter>(
  (ref) => IsolateCatalogImporter(ref.watch(databaseProvider)),
);

final importPlaylistProvider = Provider<ImportPlaylist>(
  (ref) => ImportPlaylist(
    ref.watch(credentialStoreProvider),
    ref.watch(catalogImporterProvider),
  ),
);

final buildHomeFeedProvider = Provider<BuildHomeFeed>(
  (ref) => BuildHomeFeed(
    ref.watch(catalogRepositoryProvider),
    ref.watch(trendingRepositoryProvider),
    ref.watch(watchProgressRepositoryProvider),
  ),
);

final resolveStreamUrlProvider = Provider<ResolveStreamUrl>(
  (ref) => ResolveStreamUrl(ref.watch(credentialStoreProvider)),
);

/// Crée un moteur vidéo adapté à la mémoire de l'appareil.
final playbackEngineFactoryProvider = Provider<PlaybackEngine Function()>((
  ref,
) {
  final tier = ref.watch(deviceProfileProvider).memoryTier;
  return () => MediaKitEngine(tier: tier);
});

/// Construit la surface vidéo d'un moteur, sans exposer `iptv_player` aux écrans.
final videoSurfaceBuilderProvider = Provider<Widget Function(PlaybackEngine)>(
  (ref) =>
      (engine) => VideoSurface(engine: engine as MediaKitEngine),
);
