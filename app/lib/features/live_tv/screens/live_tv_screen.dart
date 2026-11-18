import 'dart:async';
import 'dart:math' as math;

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/aero_states.dart';
import '../../../design_system/components/poster_image.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../l10n/country_names.dart';
import '../../favorites/favorites_state.dart';
import '../../player/player_target.dart';
import '../../settings/playlist/playlist_manager_screen.dart';
import '../providers/live_tv_providers.dart';

const Duration _groupPreviewDelay = Duration(milliseconds: 180);
const double _flagTileWidth = 170;

/// Clé de l'écran des favoris, distincte de tout code pays.
const String _favoritesKey = '*favoris';

/// Étoile des favoris, d'un or chaud sur le bleu.
const Color _favoriteGold = Color(0xFFFFD86B);

/// Menu d'une chaîne : la regarder, ou l'ajouter aux favoris ou l'en retirer.
Future<void> _showChannelMenu(
  BuildContext context,
  WidgetRef ref,
  Channel channel,
  Future<void> Function(Channel channel) play,
) async {
  final l10n = context.l10n;
  final key = channelFavoriteKey(channel);
  final favorite = await isFavorite(ref, ContentKind.live, key);
  if (!context.mounted) return;
  final picked = await showAeroMenu(
    context,
    title: channel.name,
    options: [
      l10n.homePlay,
      favorite ? l10n.menuRemoveFavorite : l10n.menuAddFavorite,
    ],
  );
  switch (picked) {
    case 0:
      await play(channel);
    case 1:
      await toggleFavorite(
        ref,
        kind: ContentKind.live,
        key: key,
        title: channel.name,
        posterUrl: channel.logoUrl,
      );
  }
}

/// Live TV : drapeaux, puis groupes et chaînes du pays choisi.
class LiveTvScreen extends ConsumerWidget {
  const LiveTvScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (ref.watch(activeSourceProvider) == null) {
      return AeroMessage(
        title: l10n.emptyTitle,
        body: l10n.emptyBody,
        actionLabel: l10n.actionAddPlaylist,
        onAction: () => openPlaylistManager(context),
      );
    }
    final selection = ref.watch(selectedCountryProvider);
    return selection == null
        ? const _CountryGrid()
        : _ChannelBrowser(
            key: ValueKey(selection.favorites ? _favoritesKey : selection.code),
            countryCode: selection.code,
            favorites: selection.favorites,
          );
  }
}

class _CountryGrid extends ConsumerWidget {
  const _CountryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(
      settingsProvider.select((settings) => settings.languageCode),
    );
    final hasFavorites = (ref.watch(favoritesProvider).value ?? const []).any(
      (favorite) => favorite.kind == ContentKind.live,
    );
    // La tuile des favoris précède les pays.
    final offset = hasFavorites ? 1 : 0;
    return ref
        .watch(countriesProvider)
        .when(
          loading: () => AeroLoading(label: l10n.loading),
          error: (error, _) => AeroMessage(
            title: l10n.loadErrorTitle,
            actionLabel: l10n.actionRetry,
            onAction: () => ref.invalidate(countriesProvider),
          ),
          data: (countries) {
            if (countries.isEmpty && !hasFavorites) {
              return AeroMessage(
                title: l10n.emptyCatalogTitle,
                body: l10n.emptyCatalogBody,
                actionLabel: l10n.actionOpenSettings,
                autofocus: false,
                onAction: () =>
                    ref.read(currentTabProvider.notifier).show(AppTab.settings),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.liveChooseCountry, style: AeroText.title),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => DpadCollection.grid(
                        autofocus: true,
                        memoryKey: 'live.countries',
                        itemCount: countries.length + offset,
                        itemExtent: 128,
                        columns: math.max(
                          2,
                          (constraints.maxWidth - 18) ~/ (_flagTileWidth + 18),
                        ),
                        spacing: 18,
                        padding: const EdgeInsets.all(18),
                        onSelect: (index) {
                          final selection = ref.read(
                            selectedCountryProvider.notifier,
                          );
                          index < offset
                              ? selection.selectFavorites()
                              : selection.select(
                                  countries[index - offset].code,
                                );
                        },
                        itemBuilder: (context, index, focused) => index < offset
                            ? _FlagTile(
                                code: null,
                                name: l10n.homeFavorites,
                                glyph: Icons.star_rounded,
                              )
                            : _FlagTile(
                                code: countries[index - offset].code,
                                name: _countryLabel(
                                  countries[index - offset].code,
                                  language,
                                  l10n.liveUnknownCountry,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
  }

  String _countryLabel(String? code, String language, String unknown) =>
      code == null ? unknown : countryName(code, language) ?? code;
}

class _FlagTile extends StatelessWidget {
  const _FlagTile({required this.code, required this.name, this.glyph});

  final String? code;
  final String name;

  /// Icône à la place d'un drapeau, comme l'étoile des favoris.
  final IconData? glyph;

  @override
  Widget build(BuildContext context) {
    final country = code;
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 64,
            // Les drapeaux vectoriels ne sont rasterisés qu'une seule fois.
            child: RepaintBoundary(
              child: glyph != null
                  ? Icon(glyph, color: _favoriteGold, size: 56)
                  : country != null && country.length == 2
                  ? CountryFlag.fromCountryCode(
                      country,
                      theme: const ImageTheme(
                        width: 96,
                        height: 64,
                        shape: RoundedRectangle(6),
                      ),
                    )
                  : const Icon(Icons.public, color: AeroColors.aqua, size: 52),
            ),
          ),
          const Spacer(),
          Text(
            name,
            style: AeroText.caption.copyWith(color: AeroColors.foam),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ChannelBrowser extends ConsumerStatefulWidget {
  const _ChannelBrowser({
    required this.countryCode,
    this.favorites = false,
    super.key,
  });

  final String? countryCode;

  /// Montre les chaînes favorites à la place des groupes d'un pays.
  final bool favorites;

  @override
  ConsumerState<_ChannelBrowser> createState() => _ChannelBrowserState();
}

class _ChannelBrowserState extends ConsumerState<_ChannelBrowser> {
  final FocusNode _channelsNode = FocusNode(debugLabel: 'Channels');
  Timer? _previewTimer;
  int _group = 0;

  @override
  void dispose() {
    _previewTimer?.cancel();
    _channelsNode.dispose();
    super.dispose();
  }

  /// Attend que la sélection se stabilise : parcourir les groupes ne doit pas
  /// déclencher une requête par groupe survolé.
  void _previewGroup(int index) {
    _previewTimer?.cancel();
    _previewTimer = Timer(_groupPreviewDelay, () {
      if (mounted) setState(() => _group = index);
    });
  }

  Future<void> _play(Channel channel) async {
    final source = ref.read(activeSourceProvider);
    if (source == null) return;
    final grouped = ref.read(settingsProvider).groupChannels;
    final l10n = context.l10n;
    final streams = await ref
        .read(liveTvRepositoryProvider)
        .streamsOf(source.id, channel, grouped: grouped);
    if (streams.isEmpty || !mounted) return;
    var choice = 0;
    if (streams.length > 1) {
      final picked = await showAeroMenu(
        context,
        title: l10n.liveChooseStream,
        options: [
          for (final (index, stream) in streams.indexed)
            stream.label.isEmpty
                ? l10n.liveStreamDefault(index + 1)
                : stream.label,
        ],
      );
      if (picked == null || !mounted) return;
      choice = picked;
    }
    await openPlayer(
      context,
      PlayerTarget.channel(
        source.id,
        channel,
        streams[choice],
        streams: streams,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groups = widget.favorites
        ? AsyncValue.data([
            ChannelGroup(
              key: _favoritesKey,
              displayName: l10n.homeFavorites,
              channelCount: 0,
            ),
          ])
        : ref.watch(groupsProvider(widget.countryCode));
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 32),
      child: groups.when(
        loading: () => AeroLoading(label: l10n.loading),
        error: (error, _) => AeroMessage(
          title: l10n.loadErrorTitle,
          actionLabel: l10n.actionBack,
          onAction: () => ref.read(selectedCountryProvider.notifier).clear(),
        ),
        data: (groups) {
          final selected = groups.isEmpty
              ? null
              : groups[_group.clamp(0, groups.length - 1)];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 320,
                child: GlassPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AeroButton(
                        label: l10n.actionBack,
                        icon: Icons.arrow_back,
                        onSelect: () =>
                            ref.read(selectedCountryProvider.notifier).clear(),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: DpadCollection.vertical(
                          autofocus: true,
                          memoryKey: 'live.groups.${widget.countryCode}',
                          itemCount: groups.length,
                          itemExtent: 46,
                          padding: const EdgeInsets.all(4),
                          onIndexChanged: _previewGroup,
                          onSelect: (index) {
                            _previewTimer?.cancel();
                            setState(() => _group = index);
                            _channelsNode.requestFocus();
                          },
                          itemBuilder: (context, index, focused) => _GroupRow(
                            name: groups[index].displayName.isEmpty
                                ? l10n.liveAllChannels
                                : groups[index].displayName,
                            focused: focused,
                            selected: index == _group,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: GlassPanel(
                  padding: const EdgeInsets.all(14),
                  child: selected == null
                      ? Center(
                          child: Text(
                            l10n.liveNoChannels,
                            style: AeroText.body,
                          ),
                        )
                      : widget.favorites
                      ? _ChannelList(
                          key: const ValueKey(_favoritesKey),
                          list:
                              ref.watch(favoriteChannelsProvider).value ??
                              const ChannelList(loading: true),
                          focusNode: _channelsNode,
                          onSelect: _play,
                        )
                      : _PagedChannelList(
                          key: ValueKey(selected.key),
                          query: ChannelQuery(widget.countryCode, selected),
                          focusNode: _channelsNode,
                          onSelect: _play,
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Chaînes d'un groupe, chargées page par page.
class _PagedChannelList extends ConsumerWidget {
  const _PagedChannelList({
    required this.query,
    required this.focusNode,
    required this.onSelect,
    super.key,
  });

  final ChannelQuery query;
  final FocusNode focusNode;
  final Future<void> Function(Channel channel) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _ChannelList(
    list: ref.watch(channelPagesProvider(query)),
    focusNode: focusNode,
    onSelect: onSelect,
    onEndReached: () =>
        ref.read(channelPagesProvider(query).notifier).loadMore(),
  );
}

class _ChannelList extends ConsumerWidget {
  const _ChannelList({
    required this.list,
    required this.focusNode,
    required this.onSelect,
    this.onEndReached,
    super.key,
  });

  final ChannelList list;
  final FocusNode focusNode;
  final Future<void> Function(Channel channel) onSelect;
  final VoidCallback? onEndReached;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (list.channels.isEmpty) {
      return Center(
        child: Text(
          list.loading ? l10n.loading : l10n.liveNoChannels,
          style: AeroText.body,
        ),
      );
    }
    return DpadCollection.vertical(
      focusNode: focusNode,
      itemCount: list.channels.length,
      itemExtent: 64,
      padding: const EdgeInsets.all(4),
      onSelect: (index) => onSelect(list.channels[index]),
      onLongSelect: (index) =>
          _showChannelMenu(context, ref, list.channels[index], onSelect),
      onEndReached: onEndReached,
      itemBuilder: (context, index, focused) {
        final channel = list.channels[index];
        return _ChannelRow(
          channel: channel,
          programme: list.programmes[channel.epgKey]?.title,
          focused: focused,
        );
      },
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.name,
    required this.focused,
    required this.selected,
  });

  final String name;
  final bool focused;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        name,
        style: AeroText.body.copyWith(
          color: focused
              ? AeroColors.leaf
              : selected
              ? AeroColors.aqua
              : AeroColors.foam,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.programme,
    required this.focused,
  });

  final Channel channel;
  final String? programme;
  final bool focused;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        SizedBox(
          width: 64,
          height: 44,
          child: PosterImage(
            url: channel.logoUrl,
            decodeWidth: 128,
            fit: BoxFit.contain,
            placeholder: const Icon(Icons.tv, color: AeroColors.mist, size: 26),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                channel.name,
                style: AeroText.body.copyWith(
                  color: focused ? AeroColors.leaf : AeroColors.foam,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (programme != null)
                Text(
                  programme!,
                  style: AeroText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
