import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/aero_states.dart';
import '../../../design_system/components/poster_card.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../focus/focus_memory.dart';
import '../../media_detail/open_movie.dart';
import '../../media_detail/open_series.dart';
import '../../player/player_target.dart';
import '../../settings/playlist/playlist_manager_screen.dart';
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
  return ref.watch(buildHomeFeedProvider)(
    source.id,
    language: language,
    groupSeries: groupSeries,
    region: regionFor(source, language),
  );
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
    return ref
        .watch(homeFeedProvider)
        .when(
          loading: () => AeroLoading(label: l10n.loading),
          error: (error, _) => AeroMessage(
            title: l10n.loadErrorTitle,
            actionLabel: l10n.actionRetry,
            onAction: () => ref.invalidate(homeFeedProvider),
          ),
          data: (feed) => feed == null || feed.isEmpty
              ? AeroMessage(
                  title: l10n.emptyCatalogTitle,
                  body: l10n.emptyCatalogBody,
                  actionLabel: l10n.actionOpenSettings,
                  onAction: openSettings,
                )
              : _HomeContent(feed: feed),
        );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.feed});

  final HomeFeed feed;

  /// Options d'un élément de « Continuer à regarder ».
  Future<void> _showContinueMenu(
    BuildContext context,
    WidgetRef ref,
    WatchProgress item,
  ) async {
    final l10n = context.l10n;
    final choice = await showAeroMenu(
      context,
      title: item.title,
      options: [l10n.homeResume, l10n.homeRestart, l10n.homeRemoveContinue],
    );
    if (choice == null || !context.mounted) return;
    final target = PlayerTarget.resume(item);
    switch (choice) {
      case 0:
        await openPlayer(context, target);
      case 1:
        await openPlayer(context, target.resumingAt(Duration.zero));
      case 2:
        await ref
            .read(watchProgressRepositoryProvider)
            .remove(item.sourceId, item.contentKey);
        ref.invalidate(homeFeedProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (feed.hero.isNotEmpty)
            HeroCarousel(
              items: feed.hero,
              onOpen: (item) {
                final movie = item.movie;
                final series = item.series;
                if (movie != null) {
                  openMovie(context, ref, movie);
                } else if (series != null) {
                  openSeries(context, ref, series);
                }
              },
            ),
          if (feed.continueWatching.isNotEmpty)
            _MediaRow(
              title: l10n.homeContinue,
              icon: AeroAssets.rowContinue,
              memoryKey: 'home.continue',
              itemCount: feed.continueWatching.length,
              withProgress: true,
              onSelect: (index) => openPlayer(
                context,
                PlayerTarget.resume(feed.continueWatching[index]),
              ),
              onLongSelect: (index) =>
                  _showContinueMenu(context, ref, feed.continueWatching[index]),
              itemBuilder: (context, index, focused) {
                final item = feed.continueWatching[index];
                return PosterCard(
                  title: item.title,
                  imageUrl: item.posterUrl,
                  focused: focused,
                  progress:
                      item.position.inMilliseconds /
                      item.duration.inMilliseconds,
                  progressColor: Color.lerp(
                    AeroColors.progressStart,
                    AeroColors.progressEnd,
                    index / (feed.continueWatching.length - 1).clamp(1, 20),
                  )!,
                );
              },
            ),
          if (feed.series.isNotEmpty)
            _MediaRow(
              title: l10n.homeSeries,
              icon: AeroAssets.rowSeries,
              memoryKey: 'home.series',
              itemCount: feed.series.length,
              onSelect: (index) => openSeries(context, ref, feed.series[index]),
              itemBuilder: (context, index, focused) => PosterCard(
                title: feed.series[index].title,
                imageUrl: feed.series[index].posterUrl,
                focused: focused,
              ),
            ),
          if (feed.movies.isNotEmpty)
            _MediaRow(
              title: l10n.homeMovies,
              icon: AeroAssets.rowMovies,
              memoryKey: 'home.movies',
              itemCount: feed.movies.length,
              onSelect: (index) => openMovie(context, ref, feed.movies[index]),
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

/// Rangée de l'accueil : son icône, ses cartes et des chevrons indicatifs. Les
/// emplacements vides restent visibles, comme des vitres sans image.
class _MediaRow extends ConsumerStatefulWidget {
  const _MediaRow({
    required this.title,
    required this.icon,
    required this.memoryKey,
    required this.itemCount,
    required this.itemBuilder,
    required this.onSelect,
    this.onLongSelect,
    this.withProgress = false,
  });

  final String title;
  final String icon;
  final String memoryKey;
  final int itemCount;
  final DpadItemBuilder itemBuilder;
  final ValueChanged<int> onSelect;
  final ValueChanged<int>? onLongSelect;
  final bool withProgress;

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
    final height =
        AeroMetrics.cardHeight +
        AeroMetrics.cardTitleHeight +
        (widget.withProgress ? AeroMetrics.cardProgressHeight : 0) +
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
          child: Row(
            children: [
              Image.asset(widget.icon, width: 30, height: 30),
              const SizedBox(width: 10),
              Text(widget.title, style: AeroText.heading),
            ],
          ),
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
              final pitch = AeroMetrics.cardWidth + spacing;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var slot = widget.itemCount; slot < slots; slot++)
                    PositionedDirectional(
                      start: AeroMetrics.rowGutter + slot * pitch,
                      top: _rowInset,
                      width: AeroMetrics.cardWidth,
                      height: AeroMetrics.cardHeight,
                      child: const Image(
                        image: AssetImage(AeroAssets.cardGhost),
                        fit: BoxFit.fill,
                      ),
                    ),
                  DpadCollection.horizontal(
                    memoryKey: widget.memoryKey,
                    itemCount: widget.itemCount,
                    itemExtent: AeroMetrics.cardWidth,
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
                              widget.itemCount > slots,
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
