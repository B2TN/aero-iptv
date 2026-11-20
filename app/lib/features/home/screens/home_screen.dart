import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';
import '../../../app/trends.dart';
import '../../../design_system/components/aero_states.dart';
import '../../../design_system/components/poster_card.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../focus/focus_memory.dart';
import '../../media_detail/open_continued.dart';
import '../../media_detail/open_movie.dart';
import '../../favorites/favorites_state.dart';
import '../../media_detail/open_series.dart';
import '../../media_detail/title_menu.dart';
import '../../settings/playlist/playlist_manager_screen.dart';
import '../widgets/continue_card.dart';
import '../widgets/hero_carousel.dart';

/// Contenu de l'accueil, recalculé après chaque synchronisation.
final homeFeedProvider = FutureProvider.autoDispose<HomeFeed?>((ref) async {
  final source = ref.watch(activeSourceProvider);
  if (source == null) return null;
  final language = ref.watch(
    settingsProvider.select((settings) => settings.languageCode),
  );
  final groupSeries = ref.watch(
    settingsProvider.select((settings) => settings.groupSeries),
  );
  // « Continuer à regarder » suit la dernière lecture, et les rangées les
  // tendances du jour.
  ref.watch(watchedRevisionProvider);
  ref.watch(trendsProvider);
  return ref.watch(buildHomeFeedProvider)(
    source.id,
    language: language,
    groupSeries: groupSeries,
    region: ref.watch(trendRegionProvider),
  );
});

/// Prochain épisode des séries à jour, demandé au calendrier une fois
/// l'accueil affiché : il ne l'attend pas.
final _announcedProvider =
    FutureProvider.autoDispose<Map<String, UpcomingEpisode>>((ref) async {
      final feed = await ref.watch(homeFeedProvider.future);
      if (feed == null || feed.caughtUp.isEmpty) return const {};
      return ref.watch(announcedEpisodesProvider)(feed.caughtUp);
    });

/// Film ou série de la rangée « Favoris », retrouvé dans le catalogue.
typedef _FavoriteTitle = ({Movie? movie, Series? series});

/// Favoris retrouvés dans le catalogue actuel, du plus récent au plus ancien.
/// Un favori absent du catalogue reste enregistré : il revient avec le contenu.
final _favoriteTitlesProvider =
    FutureProvider.autoDispose<List<_FavoriteTitle>>((ref) async {
      final source = ref.watch(activeSourceProvider);
      final favorites =
          ref.watch(favoritesProvider).value ?? const <Favorite>[];
      if (source == null || favorites.isEmpty) return const [];
      final language = ref.watch(
        settingsProvider.select((settings) => settings.languageCode),
      );
      final catalog = ref.watch(catalogRepositoryProvider);
      final movieKeys = {
        for (final favorite in favorites)
          if (favorite.kind == ContentKind.movie) favorite.key,
      };
      final movies = <String, List<Movie>>{};
      if (movieKeys.isNotEmpty) {
        for (final movie in await catalog.moviesByGroupingKeys(
          source.id,
          movieKeys,
        )) {
          (movies[movieFavoriteKey(movie)] ??= []).add(movie);
        }
      }
      final series = {
        for (final found in await catalog.seriesByGroupingKeys(source.id, [
          for (final favorite in favorites)
            if (favorite.kind == ContentKind.series) favorite.key,
        ], language: language))
          found.groupingKey: found,
      };
      return [
        for (final favorite in favorites)
          if (favorite.kind == ContentKind.movie)
            if (movies[favorite.key] case final versions?)
              (
                movie: movieVersionsByLanguage(versions, language).first,
                series: null,
              )
            else
              ...[]
          else if (favorite.kind == ContentKind.series)
            if (series[favorite.key] case final found?)
              (movie: null, series: found),
      ];
    });

/// Marge d'une rangée, où déborde le halo de la carte active.
const double _rowInset = 12;
const double _chevronHeight = 40;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    void openSettings() =>
        ref.read(currentTabProvider.notifier).show(AppTab.settings);

    if (!ref.watch(sourcesProvider).hasValue) {
      return AeroLoading(label: l10n.loading);
    }
    if (ref.watch(activeSourceProvider) == null) {
      return AeroMessage(
        title: l10n.emptyTitle,
        body: l10n.emptyBody,
        actionLabel: l10n.actionAddPlaylist,
        onAction: () => openPlaylistManager(context),
      );
    }
    final feedState = ref.watch(homeFeedProvider);
    // Pendant un rechargement, par exemple après une synchronisation, les
    // rangées restent en place : les remplacer par « Chargement » perdrait la
    // carte active et le défilement, et ramènerait tout en haut.
    if (feedState.hasValue) {
      final feed = feedState.value;
      return feed == null || feed.isEmpty
          ? _EmptyCatalog(onOpenSettings: openSettings)
          : _HomeContent(feed: feed);
    }
    if (feedState.hasError) {
      return AeroMessage(
        title: l10n.loadErrorTitle,
        actionLabel: l10n.actionRetry,
        onAction: () => ref.invalidate(homeFeedProvider),
      );
    }
    return AeroLoading(label: l10n.loading);
  }
}

/// Accueil d'une playlist sans contenu : son import est en cours, il a échoué,
/// ou il n'a jamais eu lieu. Les trois cas ne doivent pas se ressembler.
class _EmptyCatalog extends ConsumerWidget {
  const _EmptyCatalog({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(importControllerProvider);
    if (status.running) {
      return AeroLoading(label: importMessage(l10n, status) ?? l10n.loading);
    }
    final failure = status.failure;
    final source = ref.watch(activeSourceProvider);
    if (failure != null && source != null) {
      return AeroMessage(
        title: l10n.importFailedTitle,
        body: [
          importFailureMessage(l10n, failure),
          ?importFailureStep(l10n, status),
        ].join('\n'),
        actionLabel: l10n.actionRetry,
        onAction: () =>
            ref.read(importControllerProvider.notifier).start(source),
      );
    }
    return AeroMessage(
      title: l10n.emptyCatalogTitle,
      body: l10n.emptyCatalogBody,
      actionLabel: l10n.actionOpenSettings,
      onAction: onOpenSettings,
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.feed});

  final HomeFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final favorites =
        ref.watch(_favoriteTitlesProvider).value ?? const <_FavoriteTitle>[];
    final announced =
        ref.watch(_announcedProvider).value ??
        const <String, UpcomingEpisode>{};
    // En dernier : les séries à jour dont la suite est annoncée.
    final continued = [
      ...feed.continueWatching,
      for (final caughtUp in feed.caughtUp)
        if (announced.containsKey(caughtUp.progress.groupKey))
          caughtUp.progress,
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sans grand visuel, les rangées commencent sous la barre.
          if (feed.hero.isEmpty)
            const SizedBox(height: AeroMetrics.topBarHeight)
          else
            HeroCarousel(
              items: feed.hero,
              onOpen: (item) {
                final movie = item.movie;
                final series = item.series;
                if (movie != null) {
                  playMovie(context, ref, movie);
                } else if (series != null) {
                  openSeries(context, ref, series);
                }
              },
            ),
          if (continued.isNotEmpty)
            _MediaRow(
              title: l10n.homeContinue,
              memoryKey: 'home.continue',
              itemCount: continued.length,
              itemKeys: [for (final item in continued) item.groupKey],
              wide: true,
              onSelect: (index) =>
                  openContinued(context, ref, continued[index]),
              onLongSelect: (index) => showContinueMenu(
                context,
                ref,
                continued[index],
                caughtUp: announced.containsKey(continued[index].groupKey),
                onRemoved: () => ref.invalidate(homeFeedProvider),
              ),
              itemBuilder: (context, index, focused) {
                final item = continued[index];
                return ContinueCard(
                  item: item,
                  next: announced[item.groupKey],
                  focused: focused,
                  progressColor: Color.lerp(
                    AeroColors.progressStart,
                    AeroColors.progressEnd,
                    index / (continued.length - 1).clamp(1, 20),
                  )!,
                );
              },
            ),
          if (favorites.isNotEmpty)
            _MediaRow(
              title: l10n.homeFavorites,
              memoryKey: 'home.favorites',
              itemCount: favorites.length,
              itemKeys: [
                for (final item in favorites)
                  item.movie?.groupingKey ?? item.series?.groupingKey,
              ],
              onSelect: (index) => switch (favorites[index]) {
                (movie: final Movie movie, series: _) => openMovie(
                  context,
                  ref,
                  movie,
                ),
                (movie: _, series: final Series series) => openSeries(
                  context,
                  ref,
                  series,
                ),
                _ => Future<void>.value(),
              },
              onLongSelect: (index) => switch (favorites[index]) {
                (movie: final Movie movie, series: _) => showMovieMenu(
                  context,
                  ref,
                  movie,
                ),
                (movie: _, series: final Series series) => showSeriesMenu(
                  context,
                  ref,
                  series,
                ),
                _ => Future<void>.value(),
              },
              itemBuilder: (context, index, focused) {
                final item = favorites[index];
                return PosterCard(
                  title: item.movie?.title ?? item.series?.title ?? '',
                  imageUrl: item.movie?.posterUrl ?? item.series?.posterUrl,
                  focused: focused,
                );
              },
            ),
          if (feed.series.isNotEmpty)
            _MediaRow(
              title: l10n.homeSeries,
              memoryKey: 'home.series',
              itemCount: feed.series.length,
              itemKeys: [for (final item in feed.series) item.groupingKey],
              onSelect: (index) => openSeries(context, ref, feed.series[index]),
              onLongSelect: (index) =>
                  showSeriesMenu(context, ref, feed.series[index]),
              itemBuilder: (context, index, focused) => PosterCard(
                title: feed.series[index].title,
                imageUrl: feed.series[index].posterUrl,
                focused: focused,
              ),
            ),
          if (feed.movies.isNotEmpty)
            _MediaRow(
              title: l10n.homeMovies,
              memoryKey: 'home.movies',
              itemCount: feed.movies.length,
              itemKeys: [for (final item in feed.movies) item.groupingKey],
              onSelect: (index) => openMovie(context, ref, feed.movies[index]),
              onLongSelect: (index) =>
                  showMovieMenu(context, ref, feed.movies[index]),
              itemBuilder: (context, index, focused) => PosterCard(
                title: feed.movies[index].title,
                imageUrl: feed.movies[index].posterUrl,
                focused: focused,
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Rangée de l'accueil : son titre, ses cartes et des chevrons indicatifs.
///
/// Sa clé est celle de sa mémoire : une rangée qui apparaît au-dessus, comme
/// « Continuer à regarder » après une première lecture, ne lui prend ni son
/// état ni le focus.
class _MediaRow extends ConsumerStatefulWidget {
  _MediaRow({
    required this.title,
    required this.memoryKey,
    required this.itemCount,
    required this.itemKeys,
    required this.itemBuilder,
    required this.onSelect,
    this.onLongSelect,
    this.wide = false,
  }) : super(key: ValueKey(memoryKey));

  final String title;
  final String memoryKey;
  final int itemCount;

  /// Identité de chaque carte, pour que le focus la suive quand la rangée
  /// change d'ordre.
  final List<Object?> itemKeys;
  final DpadItemBuilder itemBuilder;
  final ValueChanged<int> onSelect;
  final ValueChanged<int>? onLongSelect;

  /// Cartes sur deux emplacements, sans titre dessous : « Continuer à
  /// regarder ».
  final bool wide;

  @override
  ConsumerState<_MediaRow> createState() => _MediaRowState();
}

class _MediaRowState extends ConsumerState<_MediaRow> {
  /// Chaque déplacement ne redessine que les chevrons.
  late final ValueNotifier<int> _index = ValueNotifier(
    ref.read(focusMemoryProvider).read(widget.memoryKey),
  );

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final span = widget.wide ? 2 : 1;
    final height =
        AeroMetrics.cardHeight +
        (widget.wide ? 0 : AeroMetrics.cardTitleHeight) +
        _rowInset * 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AeroMetrics.rowGutter,
            6,
            AeroMetrics.rowGutter,
            0,
          ),
          child: Text(widget.title, style: AeroText.heading),
        ),
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final room = constraints.maxWidth - AeroMetrics.rowGutter * 2;
              final slots = math.max(
                2,
                (room + AeroMetrics.cardSpacing) ~/
                    (AeroMetrics.cardWidth + AeroMetrics.cardSpacing),
              );
              // Les cartes occupent toute la largeur, quelle que soit la fenêtre.
              final spacing =
                  (room - slots * AeroMetrics.cardWidth) / (slots - 1);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  DpadCollection.horizontal(
                    memoryKey: widget.memoryKey,
                    itemCount: widget.itemCount,
                    itemKeys: widget.itemKeys,
                    // Une carte large couvre deux emplacements et l'écart
                    // entre eux : les colonnes restent alignées d'une
                    // rangée à l'autre.
                    itemExtent:
                        AeroMetrics.cardWidth * span + spacing * (span - 1),
                    crossExtent: height,
                    spacing: spacing,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AeroMetrics.rowGutter,
                      vertical: _rowInset,
                    ),
                    onSelect: widget.onSelect,
                    onLongSelect: widget.onLongSelect,
                    onIndexChanged: (index) => _index.value = index,
                    itemBuilder: widget.itemBuilder,
                    onFocusChange: (focused) {
                      if (focused) {
                        Scrollable.ensureVisible(
                          this.context,
                          duration: const Duration(milliseconds: 160),
                          alignment: 0.6,
                        );
                      }
                    },
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _index,
                    builder: (context, index, _) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _Chevron(lit: index > 0, forward: false),
                        _Chevron(
                          lit:
                              index < widget.itemCount - 1 &&
                              widget.itemCount * span > slots,
                          forward: true,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Indique qu'une rangée continue de ce côté.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.lit, required this.forward});

  final bool lit;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: const AssetImage(AeroAssets.chevron),
      width: 22,
      height: _chevronHeight,
      matchTextDirection: true,
      color: lit ? null : const Color(0x40FFFFFF),
      colorBlendMode: lit ? null : BlendMode.modulate,
    );
    return PositionedDirectional(
      start: forward ? null : 22,
      end: forward ? 22 : null,
      top: _rowInset + (AeroMetrics.cardHeight - _chevronHeight) / 2,
      child: IgnorePointer(
        child: forward ? Transform.flip(flipX: true, child: image) : image,
      ),
    );
  }
}
