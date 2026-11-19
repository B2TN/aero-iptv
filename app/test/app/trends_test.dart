import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/app/trends.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

final class _Trending implements TrendingRepository {
  final Map<String, DateTime> _loaded = {};
  final List<String> refreshed = [];
  bool down = false;
  DateTime now = DateTime(2026, 11, 19, 20);

  @override
  bool get isAvailable => true;

  @override
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    String? region,
  }) async => const [];

  @override
  Future<DateTime?> refreshedAt(String region) async => _loaded[region];

  @override
  Future<void> refresh(String region, {required String language}) async {
    if (down) throw const NetworkFailure('hors ligne');
    refreshed.add(region);
    _loaded[region] = now;
  }
}

/// Région de l'appareil, que le test change.
class _Region extends Notifier<String?> {
  @override
  String? build() => 'FR';

  void set(String? region) => state = region;
}

final _regionProvider = NotifierProvider<_Region, String?>(_Region.new);

void main() {
  late _Trending trending;
  late ProviderContainer container;

  setUp(() {
    trending = _Trending();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        systemRegionProvider.overrideWith((ref) => ref.watch(_regionProvider)),
        refreshTrendingProvider.overrideWithValue(
          RefreshTrending(trending, clock: () => trending.now),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('actualise au plus une fois par jour', () async {
    final trends = container.read(trendsProvider.notifier);

    await trends.check();
    await trends.check();
    expect(trending.refreshed, ['FR']);
    // L'accueil se recompose après l'actualisation.
    expect(container.read(trendsProvider), 1);

    trending.now = trending.now.add(const Duration(days: 1));
    await trends.check();
    expect(trending.refreshed, ['FR', 'FR']);
  });

  test('un autre pays a ses propres tendances', () async {
    final trends = container.read(trendsProvider.notifier);
    await trends.check();

    container.read(_regionProvider.notifier).set('BE');
    container.read(trendRegionProvider);
    await pumpEventQueue();

    expect(trending.refreshed, ['FR', 'BE']);
  });

  test('sans région, la langue de l application décide', () {
    container.read(_regionProvider.notifier).set(null);

    expect(container.read(trendRegionProvider), 'FR');
  });

  test('sans réseau, l accueil ne change pas', () async {
    trending.down = true;

    await container.read(trendsProvider.notifier).check();

    expect(container.read(trendsProvider), 0);
  });
}
