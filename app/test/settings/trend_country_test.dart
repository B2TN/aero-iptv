import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/app/platform/device_profile.dart';
import 'package:aero_iptv/app/trends.dart';
import 'package:aero_iptv/features/settings/screens/settings_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/iptv_player.dart' show MemoryTier;

final class _Settings implements SettingsRepository {
  _Settings(this.value);

  AppSettings value;
  final StreamController<AppSettings> _changes =
      StreamController<AppSettings>.broadcast();

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

final class _Locator implements CountryLocator {
  @override
  Future<String> country() async => 'CH';
}

final class _Trending implements TrendingRepository {
  final List<String> refreshed = [];

  @override
  bool get isAvailable => true;

  @override
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    String? region,
  }) async => const [];

  @override
  Future<DateTime?> refreshedAt(String region) async => null;

  @override
  Future<void> refresh(String region, {required String language}) async =>
      refreshed.add(region);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('choisit le pays des tendances, ou revient à Automatique', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1920, 1080)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = _Settings(const AppSettings(detectedCountry: 'BE'));
    final trending = _Trending();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settings),
          deviceProfileProvider.overrideWithValue(
            const DeviceProfile(memoryTier: MemoryTier.standard, isTv: true),
          ),
          sourcesProvider.overrideWith(
            (ref) => Stream.value(const <PlaylistSource>[]),
          ),
          systemRegionProvider.overrideWithValue('FR'),
          countryLocatorProvider.overrideWithValue(_Locator()),
          refreshTrendingProvider.overrideWithValue(RefreshTrending(trending)),
        ],
        child: WidgetsApp(
          color: const Color(0xFF000000),
          locale: const Locale('fr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          shortcuts: dpadShortcuts,
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, _) => builder(context),
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Catalogue'));
    await _settle(tester);
    // Le pays détecté est affiché.
    expect(find.text('Automatique (Belgique)'), findsOneWidget);

    await tester.tap(find.text('Pays des tendances'));
    await _settle(tester);
    await tester.tap(find.text('Espagne'));
    await _settle(tester);

    expect(settings.value.trendCountry, 'ES');
    expect(find.text('Espagne'), findsOneWidget);
    expect(trending.refreshed, contains('ES'));

    await tester.tap(find.text('Pays des tendances'));
    await _settle(tester);
    await tester.tap(find.text('Automatique (Belgique)'));
    await _settle(tester);

    // Le pays est redemandé.
    expect(settings.value.trendCountry, isNull);
    expect(settings.value.detectedCountry, 'CH');
    expect(find.text('Automatique (Suisse)'), findsOneWidget);
    expect(trending.refreshed.last, 'CH');
  });
}
