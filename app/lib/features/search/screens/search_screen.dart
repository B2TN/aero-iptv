import '../../../design_system/components/keyboard_field.dart';
import '../../../app/di/infrastructure_providers.dart';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_states.dart';
import '../../../design_system/components/poster_card.dart';
import '../../../design_system/components/virtual_keyboard.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/components/focus_row.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../home/screens/home_screen.dart';
import '../../media_detail/open_movie.dart';
import '../../media_detail/open_series.dart';
import '../../media_detail/title_menu.dart';
import '../../settings/playlist/playlist_manager_screen.dart';

const Duration _inputDebounce = Duration(milliseconds: 180);
const int _maxTrending = 24;
const double _gridPadding = 16;
const double _gridSpacing = 18;

class SearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider.autoDispose<SearchQuery, String>(
  SearchQuery.new,
);

final _suggestionsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider).trim();
  final source = ref.watch(activeSourceProvider);
  if (query.isEmpty || source == null) return const [];
  await Future<void>.delayed(_inputDebounce);
  if (!ref.mounted) return const [];
  return ref.watch(searchRepositoryProvider).suggest(source.id, query);
});

final _resultsProvider = FutureProvider.autoDispose<List<SearchHit>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider).trim();
  final source = ref.watch(activeSourceProvider);
  final language = ref.watch(settingsProvider.select((s) => s.languageCode));
  final groupMovies = ref.watch(settingsProvider.select((s) => s.groupMovies));
  if (query.isEmpty || source == null) return const [];
  await Future<void>.delayed(_inputDebounce);
  if (!ref.mounted) return const [];
  final page = await ref
      .watch(searchRepositoryProvider)
      .search(
        source.id,
        query,
        const PageRequest(limit: 40),
        language: language,
        groupMovies: groupMovies,
      );
  return page.items;
});

/// Élément affiché à droite, qu'il vienne des tendances ou de la recherche.
typedef _Opener = Future<void> Function(BuildContext context, WidgetRef ref);

final class _GridItem {
  const _GridItem({
    required this.title,
    required this.imageUrl,
    required this.open,
    required this.menu,
  });

  final String title;
  final String? imageUrl;
  final _Opener open;

  /// Menu de l'appui long, de la touche Menu et du clic droit.
  final _Opener menu;
}

/// Recherche : clavier et suggestions à gauche, résultats à droite.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  /// Retrouve le film ou la série d'un résultat, puis l'ouvre ou montre son
  /// menu selon [withMenu].
  Future<void> _openHit(
    BuildContext context,
    WidgetRef ref,
    SearchHit hit, {
    bool withMenu = false,
  }) async {
    final source = ref.read(activeSourceProvider);
    if (source == null) return;
    final catalog = ref.read(catalogRepositoryProvider);
    if (hit.kind == ContentKind.movie) {
      final movie = await catalog.movieById(hit.id);
      if (movie != null && context.mounted) {
        await (withMenu ? showMovieMenu : openMovie)(context, ref, movie);
      }
      return;
    }
    final series = await catalog.seriesById(hit.id);
    if (series != null && context.mounted) {
      await (withMenu ? showSeriesMenu : openSeries)(context, ref, series);
    }
  }

  List<_GridItem> _trending(HomeFeed? feed, int sourceId) {
    if (feed == null) return const [];
    return [
      for (final series in feed.series)
        _GridItem(
          title: series.title,
          imageUrl: series.posterUrl,
          open: (context, ref) => openSeries(context, ref, series),
          menu: (context, ref) => showSeriesMenu(context, ref, series),
        ),
      for (final movie in feed.movies)
        _GridItem(
          title: movie.title,
          imageUrl: movie.posterUrl,
          open: (context, ref) => openMovie(context, ref, movie),
          menu: (context, ref) => showMovieMenu(context, ref, movie),
        ),
    ].take(_maxTrending).toList(growable: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final source = ref.watch(activeSourceProvider);
    if (source == null) {
      return AeroMessage(
        title: l10n.emptyTitle,
        body: l10n.emptyBody,
        actionLabel: l10n.actionAddPlaylist,
        onAction: () => openPlaylistManager(context),
      );
    }

    final query = ref.watch(searchQueryProvider);
    final isSearching = query.trim().isNotEmpty;
    final suggestions = ref.watch(_suggestionsProvider).value ?? const [];
    final results = ref.watch(_resultsProvider);
    final hits = results.value ?? const <SearchHit>[];
    // « Aucun résultat » attend la fin de la recherche : pendant la frappe et
    // la requête, la liste vide n'est qu'en attente.
    final pending = isSearching && (results.isLoading || !results.hasValue);
    final items = isSearching
        ? [
            for (final hit in hits)
              _GridItem(
                title: hit.title,
                imageUrl: hit.posterUrl,
                open: (context, ref) => _openHit(context, ref, hit),
                menu: (context, ref) =>
                    _openHit(context, ref, hit, withMenu: true),
              ),
          ]
        : _trending(ref.watch(homeFeedProvider).value, source.id);
    final isArabic =
        ref.watch(settingsProvider.select((s) => s.languageCode)) == 'ar';

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 396,
            child: GlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ref.watch(physicalKeyboardProvider))
                    _SearchField(hint: l10n.searchPrompt)
                  else ...[
                    Text(
                      query.isEmpty ? l10n.searchPrompt : query,
                      style: query.isEmpty ? AeroText.body : AeroText.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    VirtualKeyboard(
                      autofocus: true,
                      keySize: 44,
                      memoryKey: 'search.keyboard',
                      layouts: isArabic
                          ? const [KeyboardLayout.arabic, KeyboardLayout.lower]
                          : const [KeyboardLayout.lower],
                      onCharacter: (value) => ref
                          .read(searchQueryProvider.notifier)
                          .set(query + value),
                      onAction: (action) {
                        final notifier = ref.read(searchQueryProvider.notifier);
                        if (action == KeyboardAction.space) {
                          notifier.set('$query ');
                        } else if (query.isNotEmpty) {
                          notifier.set(query.substring(0, query.length - 1));
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: DpadCollection.vertical(
                      itemCount: suggestions.length,
                      itemExtent: 34,
                      spacing: 2,
                      padding: const EdgeInsets.all(2),
                      onSelect: (index) => ref
                          .read(searchQueryProvider.notifier)
                          .set(suggestions[index]),
                      itemBuilder: (context, index, focused) => FocusRow(
                        focused: focused,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            suggestions[index],
                            style: AeroText.body.copyWith(
                              color: rowInk(focused: focused),
                              fontWeight: focused ? FontWeight.w600 : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSearching ? l10n.searchResults : l10n.searchTrending,
                  style: AeroText.title,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: isSearching && items.isEmpty
                      ? pending
                            ? AeroLoading(label: l10n.searchSearching)
                            : Center(
                                child: Text(
                                  results.hasError
                                      ? l10n.loadErrorTitle
                                      : l10n.searchNoResult(query.trim()),
                                  style: AeroText.body,
                                ),
                              )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final room =
                                constraints.maxWidth - _gridPadding * 2;
                            final columns = math.max(
                              2,
                              (room + _gridSpacing) ~/
                                  (AeroMetrics.cardWidth + _gridSpacing),
                            );
                            final width =
                                (room - (columns - 1) * _gridSpacing) / columns;
                            return DpadCollection.grid(
                              itemCount: items.length,
                              itemExtent:
                                  width *
                                      AeroMetrics.cardHeight /
                                      AeroMetrics.cardWidth +
                                  AeroMetrics.cardTitleHeight,
                              columns: columns,
                              spacing: _gridSpacing,
                              padding: const EdgeInsets.all(_gridPadding),
                              onSelect: (index) =>
                                  items[index].open(context, ref),
                              onLongSelect: (index) =>
                                  items[index].menu(context, ref),
                              itemBuilder: (context, index, focused) =>
                                  PosterCard(
                                    title: items[index].title,
                                    imageUrl: items[index].imageUrl,
                                    focused: focused,
                                  ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recherche au clavier physique, sur PC. Le texte suit la requête : choisir
/// une suggestion le remplace.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.hint});

  final String hint;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(searchQueryProvider),
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onEdit);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEdit() {
    if (_controller.text != ref.read(searchQueryProvider)) {
      ref.read(searchQueryProvider.notifier).set(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchQueryProvider, (_, query) {
      if (query != _controller.text) {
        _controller.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length),
        );
      }
    });
    return KeyboardField(
      controller: _controller,
      hint: widget.hint,
      autofocus: true,
    );
  }
}
