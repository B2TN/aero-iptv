import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';

const int _pageSize = 50;

/// Pays ouvert. Le type distingue « aucun choix » du pays inconnu (`code` nul).
final class CountrySelection {
  const CountrySelection(this.code);

  final String? code;
}

class SelectedCountry extends Notifier<CountrySelection?> {
  @override
  CountrySelection? build() {
    final fallback = ref.watch(
      activeSourceProvider.select((source) => source?.defaultCountryCode),
    );
    return fallback == null ? null : CountrySelection(fallback);
  }

  void select(String? code) => state = CountrySelection(code);

  void clear() => state = null;
}

final selectedCountryProvider =
    NotifierProvider<SelectedCountry, CountrySelection?>(SelectedCountry.new);

final countriesProvider = FutureProvider.autoDispose<List<Country>>((
  ref,
) async {
  final source = ref.watch(activeSourceProvider);
  if (source == null) return const [];
  return ref.watch(liveTvRepositoryProvider).countries(source.id);
});

final groupsProvider = FutureProvider.autoDispose
    .family<List<ChannelGroup>, String?>((ref, countryCode) async {
      final source = ref.watch(activeSourceProvider);
      if (source == null) return const [];
      final grouped = ref.watch(
        settingsProvider.select((settings) => settings.groupChannels),
      );
      return ref
          .watch(liveTvRepositoryProvider)
          .groups(source.id, countryCode, grouped: grouped);
    });

/// Identifie la liste de chaînes d'un groupe.
final class ChannelQuery {
  const ChannelQuery(this.countryCode, this.group);

  final String? countryCode;
  final ChannelGroup group;

  @override
  bool operator ==(Object other) =>
      other is ChannelQuery &&
      other.countryCode == countryCode &&
      other.group.key == group.key &&
      other.group.rawGroupId == group.rawGroupId;

  @override
  int get hashCode => Object.hash(countryCode, group.key, group.rawGroupId);
}

/// Chaînes déjà chargées et émissions en cours.
final class ChannelList {
  const ChannelList({
    this.channels = const [],
    this.programmes = const {},
    this.hasMore = true,
    this.loading = false,
  });

  final List<Channel> channels;
  final Map<String, EpgProgramme> programmes;
  final bool hasMore;
  final bool loading;
}

/// Charge les chaînes d'un groupe page par page.
class ChannelPages extends Notifier<ChannelList> {
  ChannelPages(this.query);

  final ChannelQuery query;

  @override
  ChannelList build() {
    Future.microtask(loadMore);
    return const ChannelList(loading: true);
  }

  Future<void> loadMore() async {
    final source = ref.read(activeSourceProvider);
    final current = state;
    if (source == null || !current.hasMore) return;
    if (current.channels.isNotEmpty && current.loading) return;
    state = ChannelList(
      channels: current.channels,
      programmes: current.programmes,
      loading: true,
    );

    final page = await ref
        .read(liveTvRepositoryProvider)
        .channels(
          source.id,
          query.countryCode,
          query.group,
          PageRequest(offset: current.channels.length, limit: _pageSize),
          grouped: ref.read(settingsProvider).groupChannels,
        );
    final keys = page.items.map((channel) => channel.epgKey).nonNulls;
    final programmes = await ref
        .read(epgRepositoryProvider)
        .nowPlaying(source.id, keys, DateTime.now());
    if (!ref.mounted) return;
    state = ChannelList(
      channels: [...current.channels, ...page.items],
      programmes: {...current.programmes, ...programmes},
      hasMore: page.hasMore,
    );
  }
}

final channelPagesProvider = NotifierProvider.autoDispose
    .family<ChannelPages, ChannelList, ChannelQuery>(ChannelPages.new);
