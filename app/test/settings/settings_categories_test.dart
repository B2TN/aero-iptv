import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/platform/api_key_store.dart';
import 'package:aero_iptv/app/platform/device_profile.dart';
import 'package:aero_iptv/features/settings/screens/settings_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/iptv_player.dart' show MemoryTier;

final PlaylistSource _source = PlaylistSource(
  id: 1,
  name: 'Essai',
  kind: SourceKind.xtream,
  lastSyncReport: SyncReport(
    finishedAt: DateTime(2026, 11, 20, 8, 12),
    full: false,
    steps: const [
      SyncStep(SyncPhase.connection, Duration(milliseconds: 1200)),
      SyncStep(
        SyncPhase.movies,
        Duration(milliseconds: 9600),
        received: 200000,
        changed: 400,
      ),
      SyncStep(SyncPhase.guide, Duration(seconds: 65), received: 5000),
    ],
  ),
);

Future<ProviderContainer> _open(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        sourcesProvider.overrideWith((ref) => Stream.value([_source])),
        deviceProfileProvider.overrideWithValue(
          const DeviceProfile(memoryTier: MemoryTier.standard, isTv: true),
        ),
        apiKeyStoreProvider.overrideWithValue(const MemorylessApiKeyStore()),
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
  return ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  testWidgets('les catégories mènent à leurs réglages, et Retour y revient', (
    tester,
  ) async {
    final container = await _open(tester);
    expect(_focused, 'SettingsCategories');
    expect(find.text('Synchroniser chaque jour'), findsOneWidget);

    // Descendre change les réglages affichés, sans quitter les catégories.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('Regrouper les versions des séries'), findsOneWidget);
    expect(find.text('Synchroniser chaque jour'), findsNothing);
    expect(_focused, 'SettingsCategories');

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focused, 'SettingsRows');
    expect(container.read(settingsPaneProvider), isTrue);

    // Retour, que la coquille confie aux Paramètres.
    container.read(settingsPaneProvider.notifier).close();
    await _settle(tester);
    expect(_focused, 'SettingsCategories');
    expect(find.text('Regrouper les versions des séries'), findsOneWidget);
  });

  testWidgets('la dernière synchronisation montre son relevé', (tester) async {
    await _open(tester);
    expect(find.text('20 nov. 08:12, 1 min 16 s'), findsOneWidget);

    await tester.tap(find.text('Dernière synchronisation'));
    await _settle(tester);

    expect(find.text('Films'), findsOneWidget);
    // Les milliers sont séparés comme le veut la langue.
    expect(find.text('10 s, 200 000 reçus, 400 modifiés'), findsOneWidget);
    expect(find.text('1 min 5 s, 5 000 programmes'), findsOneWidget);
    expect(find.text('1 min 16 s'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await _settle(tester);
    expect(find.text('Films'), findsNothing);
  });
}
