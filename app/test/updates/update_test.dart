import 'dart:io';

import 'package:aero_iptv/app/daily_sync.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/app/platform/update_installer.dart';
import 'package:aero_iptv/features/updates/release_notes_screen.dart';
import 'package:aero_iptv/features/updates/update_banner.dart';
import 'package:aero_iptv/features/updates/update_controller.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_domain/iptv_domain.dart';

const String _notes = '''
## What changed

- **Daily sync** in about 30 seconds
- Episodes button in the player

| Device | File |
|---|---|
| Fire TV | `aero-iptv-fire-tv-armeabi-v7a.apk` |
''';

AppRelease _release(String tag, {bool withApk = true}) => AppRelease(
  version: AppVersion.tryParse(tag)!,
  tag: tag,
  notes: _notes,
  pageUrl: 'https://github.com/B2TN/aero-iptv/releases/tag/$tag',
  assets: {
    if (withApk)
      'update.apk': const ReleaseAsset(
        url: 'https://dl.example/update.apk',
        size: 4,
      ),
  },
);

final class _Releases implements ReleaseRepository {
  _Releases(this.items);

  List<AppRelease> items;
  int calls = 0;

  @override
  Future<List<AppRelease>> releases() async {
    calls++;
    return items;
  }
}

final class _Settings implements SettingsRepository {
  _Settings(this.current);

  AppSettings current;

  @override
  Stream<AppSettings> watch() => Stream.value(current);

  @override
  Future<void> save(AppSettings settings) async => current = settings;
}

final class _Installer implements UpdateInstaller {
  bool allowed = true;
  int settingsOpened = 0;
  final List<List<int>> installed = [];

  @override
  String get assetName => 'update.apk';

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<void> openInstallSettings() async => settingsOpened++;

  @override
  Future<void> install(File file) async =>
      installed.add(await file.readAsBytes());
}

void main() {
  late Directory downloads;

  setUp(() async {
    downloads = await Directory.systemTemp.createTemp('aero_updates');
  });

  tearDown(() => downloads.delete(recursive: true));

  ProviderContainer container({
    required _Releases releases,
    required _Settings settings,
    _Installer? installer,
    String version = '0.2.0',
  }) {
    final result = ProviderContainer(
      overrides: [
        appVersionProvider.overrideWithValue(AppVersion.tryParse(version)),
        releaseRepositoryProvider.overrideWithValue(releases),
        settingsRepositoryProvider.overrideWithValue(settings),
        updateInstallerProvider.overrideWithValue(installer ?? _Installer()),
        updateDirectoryProvider.overrideWithValue(() async => downloads),
        httpClientProvider.overrideWithValue(
          MockClient((_) async => http.Response.bytes([1, 2, 3, 4], 200)),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 19, 9)),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  group('vérification', () {
    test('propose la version officielle plus récente', () async {
      final updates = container(
        releases: _Releases([_release('v0.2.1'), _release('v0.2.2-beta.1')]),
        settings: _Settings(const AppSettings()),
      );

      await updates.read(updateControllerProvider.notifier).check();

      expect(updates.read(updateControllerProvider).release?.tag, 'v0.2.1');
    });

    test('les mises à jour bêta proposent aussi les préversions', () async {
      final updates = container(
        releases: _Releases([_release('v0.2.1'), _release('v0.2.2-beta.1')]),
        settings: _Settings(const AppSettings(betaUpdates: true)),
      );

      await updates.read(updateControllerProvider.notifier).check();

      expect(
        updates.read(updateControllerProvider).release?.tag,
        'v0.2.2-beta.1',
      );
    });

    test('fermer le bandeau l écarte jusqu à la version suivante', () async {
      final releases = _Releases([_release('v0.2.1')]);
      final settings = _Settings(const AppSettings());
      final updates = container(releases: releases, settings: settings);
      final controller = updates.read(updateControllerProvider.notifier);

      await controller.check();
      await controller.dismiss();
      expect(settings.current.dismissedUpdate, 'v0.2.1');
      await controller.check();
      expect(updates.read(updateControllerProvider).release, isNull);

      releases.items = [_release('v0.2.1'), _release('v0.2.2')];
      await controller.check();
      expect(updates.read(updateControllerProvider).release?.tag, 'v0.2.2');
    });

    test('un build de développement ne cherche rien', () async {
      final releases = _Releases([_release('v0.2.1')]);
      final updates = ProviderContainer(
        overrides: [
          appVersionProvider.overrideWithValue(null),
          releaseRepositoryProvider.overrideWithValue(releases),
        ],
      );
      addTearDown(updates.dispose);

      await updates.read(updateControllerProvider.notifier).check();

      expect(releases.calls, 0);
    });

    test('une seule vérification par 24 h', () async {
      final releases = _Releases([_release('v0.2.1')]);
      final updates = container(
        releases: releases,
        settings: _Settings(const AppSettings()),
      );
      final controller = updates.read(updateControllerProvider.notifier);

      await controller.check();
      await controller.checkIfDue();

      expect(releases.calls, 1);
    });
  });

  group('installation', () {
    test('télécharge puis confie le fichier à l installateur', () async {
      final installer = _Installer();
      final updates = container(
        releases: _Releases([_release('v0.2.1')]),
        settings: _Settings(const AppSettings()),
        installer: installer,
      );
      final controller = updates.read(updateControllerProvider.notifier);

      await controller.check();
      await controller.install();

      expect(installer.installed, [
        [1, 2, 3, 4],
      ]);
      expect(updates.read(updateControllerProvider).phase, UpdatePhase.offered);
    });

    test('sans autorisation, ouvre le réglage d Android', () async {
      final installer = _Installer()..allowed = false;
      final updates = container(
        releases: _Releases([_release('v0.2.1')]),
        settings: _Settings(const AppSettings()),
        installer: installer,
      );
      final controller = updates.read(updateControllerProvider.notifier);

      await controller.check();
      await controller.install();

      expect(installer.settingsOpened, 1);
      expect(installer.installed, isEmpty);
      expect(
        updates.read(updateControllerProvider).phase,
        UpdatePhase.needsPermission,
      );
    });
  });

  group('écran', () {
    Future<ProviderContainer> pump(WidgetTester tester, Widget home) async {
      tester.view
        ..physicalSize = const Size(1280, 720)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final updates = container(
        releases: _Releases([_release('v0.2.1')]),
        settings: _Settings(const AppSettings()),
      );
      await tester.runAsync(
        () => updates.read(updateControllerProvider.notifier).check(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: updates,
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
            home: home,
          ),
        ),
      );
      await tester.pump();
      return updates;
    }

    testWidgets('le bandeau annonce la version et ses trois boutons', (
      tester,
    ) async {
      await pump(tester, const Center(child: UpdateBanner()));

      expect(find.text('Version 0.2.1 disponible'), findsOneWidget);
      expect(find.text('Mettre à jour'), findsOneWidget);
      expect(find.bySemanticsLabel('Notes de version'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('les notes rendent le Markdown, et se ferment', (tester) async {
      await pump(tester, const Center(child: UpdateBanner()));

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      await tester.pump();

      expect(find.byType(ReleaseNotesScreen), findsOneWidget);
      expect(find.text('Nouveautés de la version 0.2.1'), findsOneWidget);
      expect(find.text('What changed'), findsOneWidget);
      expect(find.textContaining('Episodes button'), findsOneWidget);
      // Le tableau : ses cellules, sans la ligne de séparation.
      expect(find.text('Device'), findsOneWidget);
      expect(find.text('aero-iptv-fire-tv-armeabi-v7a.apk'), findsOneWidget);
      expect(find.textContaining('---'), findsNothing);

      await tester.tap(find.text('Fermer'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ReleaseNotesScreen), findsNothing);
    });
  });
}
