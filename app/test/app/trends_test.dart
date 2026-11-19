import 'dart:async';

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

/// country.is simulé : il répond [answer], ou se tait.
final class _Locator implements CountryLocator {
  String? answer = 'BE';
  int calls = 0;

  @override
  Future<String> country() async {
    calls++;
    return answer ?? (throw const NetworkFailure('hors ligne'));
  }
}

final class _Settings implements SettingsRepository {
  AppSettings value = const AppSettings();
  final StreamController<AppSettings> _changes =
      StreamController<AppSettings>.broadcast();

  /// Abonné aux modifications dès l'écoute : aucune ne se perd.
  @override
  Stream<AppSettings> watch() {
    final stream = StreamController<AppSettings>();
    StreamSubscription<AppSettings>? changes;
    stream
      ..onListen = () {
        stream.add(value);
        changes = _changes.stream.listen(stream.add);
      }
      // Sans attendre : l'horloge simulée des tests n'y arriverait pas.
      ..onCancel = () {
        unawaited(changes?.cancel());
        unawaited(stream.close());
      };
    return stream.stream;
  }

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
    _changes.add(settings);
  }
}

void main() {
  late _Trending trending;
  late _Locator locator;
  late _Settings settings;
  late ProviderContainer container;

  setUp(() {
    trending = _Trending();
    locator = _Locator();
    settings = _Settings();
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        systemRegionProvider.overrideWithValue('FR'),
        countryLocatorProvider.overrideWithValue(locator),
        refreshTrendingProvider.overrideWithValue(
          RefreshTrending(trending, clock: () => trending.now),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Comme l'accueil, qui suit les tendances : sans écoute, Riverpod met les
    // abonnements du contrôleur en pause.
    container.listen(trendsProvider, (_, _) {});
  });

  Future<void> check() async {
    await container.read(trendsProvider.notifier).check();
    await pumpEventQueue();
  }

  Future<void> choose(String? country) async {
    await container.read(trendsProvider.notifier).choose(country);
    await pumpEventQueue();
  }

  test('demande le pays une fois, puis s en sert', () async {
    await check();
    await check();

    expect(locator.calls, 1);
    expect(settings.value.detectedCountry, 'BE');
    expect(trending.refreshed, ['BE']);
    // L'accueil se recompose après l'actualisation.
    expect(container.read(trendsProvider), 1);
  });

  test('actualise au plus une fois par jour', () async {
    await check();
    await check();
    expect(trending.refreshed, ['BE']);

    trending.now = trending.now.add(const Duration(days: 1));
    await check();
    expect(trending.refreshed, ['BE', 'BE']);
  });

  test('sans réponse, la région de l appareil sert, sans redemander', () async {
    locator.answer = null;

    await check();
    await check();

    expect(locator.calls, 1);
    expect(trending.refreshed, ['FR']);
  });

  test('un pays choisi passe avant, sans rien demander', () async {
    await choose('ES');

    expect(locator.calls, 0);
    expect(trending.refreshed, ['ES']);
    expect(container.read(trendRegionProvider), 'ES');
  });

  test('« Automatique » redemande le pays', () async {
    await check();
    await choose('IT');
    locator.answer = 'CH';

    await choose(null);

    expect(locator.calls, 2);
    expect(settings.value.trendCountry, isNull);
    expect(trending.refreshed, ['BE', 'IT', 'CH']);
  });

  test('sans réseau, l accueil ne change pas', () async {
    trending.down = true;

    await check();

    expect(container.read(trendsProvider), 0);
  });

  test('sans pays connu, la langue de l application décide', () {
    expect(automaticRegion(const AppSettings(languageCode: 'de'), null), 'DE');
    expect(
      automaticRegion(
        const AppSettings(languageCode: 'de', detectedCountry: 'AT'),
        'DE',
      ),
      'AT',
    );
  });
}
