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
import '../../player/player_target.dart';
import '../../settings/playlist/playlist_manager_screen.dart';
import '../providers/live_tv_providers.dart';

const Duration _groupPreviewDelay = Duration(milliseconds: 180);
const double _flagTileWidth = 170;

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
            key: ValueKey(selection.code),
            countryCode: selection.code,
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
            if (countries.isEmpty) {
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
                        itemCount: countries.length,
                        itemExtent: 128,
                        columns: math.max(
                          2,
                          (constraints.maxWidth - 18) ~/ (_flagTileWidth + 18),
                        ),
                        spacing: 18,
                        padding: const EdgeInsets.all(18),
                        onSelect: (index) => ref
                            .read(selectedCountryProvider.notifier)
                            .select(countries[index].code),
                        itemBuilder: (context, index, focused) => _FlagTile(
                          code: countries[index].code,
                          name: _countryLabel(
                            countries[index].code,
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
  const _FlagTile({required this.code, required this.name});

  final String? code;
  final String name;

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
              child: country != null && country.length == 2
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
  const _ChannelBrowser({required this.countryCode, super.key});

  final String? countryCode;

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
    final groups = ref.watch(groupsProvider(widget.countryCode));
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
                      : _ChannelList(
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

class _ChannelList extends ConsumerWidget {
  const _ChannelList({
    required this.query,
    required this.focusNode,
    required this.onSelect,
    super.key,
  });

  final ChannelQuery query;
  final FocusNode focusNode;
  final ValueChanged<Channel> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(channelPagesProvider(query));
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
      onEndReached: () =>
          ref.read(channelPagesProvider(query).notifier).loadMore(),
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
