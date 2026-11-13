import 'dart:async';

import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/design_system/components/subtitle_text.dart';
import 'package:aero_iptv/features/settings/screens/settings_screen.dart';
import 'package:aero_iptv/features/settings/screens/subtitle_appearance_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/platform/device_profile.dart';
import 'package:iptv_player/iptv_player.dart' show MemoryTier;

/// Réglages en mémoire, qui publient chaque enregistrement.
final class _Settings implements SettingsRepository {
  final StreamController<AppSettings> _changes =
      StreamController<AppSettings>.broadcast();
  AppSettings current = const AppSettings();

  @override
  Stream<AppSettings> watch() async* {
    yield current;
    yield* _changes.stream;
  }

  @override
  Future<void> save(AppSettings settings) async {
    current = settings;
    _changes.add(settings);
  }
}

final class _NoSources implements PlaylistRepository {
  @override
  Stream<List<PlaylistSource>> watchSources() => Stream.value(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Settings> _pump(WidgetTester tester, Widget home) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = _Settings();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        deviceProfileProvider.overrideWithValue(_profile),
        playlistRepositoryProvider.overrideWithValue(_NoSources()),
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
        home: home,
      ),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  return settings;
}

Future<void> _tapAndSettle(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Text _sample(WidgetTester tester) =>
    tester.widget<Text>(find.text('On remonte avant la tempête.'));

/// Appareil à mémoire ordinaire : le mode Aero, sauf choix contraire.
const DeviceProfile _profile = DeviceProfile(
  memoryTier: MemoryTier.standard,
  isTv: true,
);

void main() {
  group('subtitleTextStyle', () {
    test('l apparence d origine ne change rien', () {
      final style = subtitleTextStyle(const SubtitleStyle());

      expect(style.fontSize, 28);
      expect(style.color, const Color(0xFFFFFFFF));
      expect(style.fontWeight, FontWeight.w500);
      expect(style.shadows, hasLength(4));
      expect(subtitleBackgroundColor(const SubtitleStyle()), isNull);
    });

    test('suit la taille, la couleur, la police et le contour', () {
      final style = subtitleTextStyle(
        const SubtitleStyle(
          size: SubtitleSize.extraLarge,
          color: SubtitleColor.yellow,
          font: SubtitleFont.bold,
          edge: SubtitleEdge.none,
        ),
      );

      expect(style.fontSize, 42);
      expect(style.color, const Color(0xFFFFF06A));
      expect(style.fontWeight, FontWeight.w700);
      expect(style.shadows, isNull);
    });

    test('le fond prend son opacité', () {
      final color = subtitleBackgroundColor(
        const SubtitleStyle(
          background: SubtitleBackground.black,
          backgroundOpacity: 75,
        ),
      );

      expect(color?.a, closeTo(0.75, 0.01));
    });
  });

  testWidgets('en haut, la réplique passe au-dessus de l image', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cue = ValueNotifier('Bonjour');
    addTearDown(cue.dispose);
    Future<double> top(SubtitlePosition position) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SubtitleLayer(
            text: cue,
            style: SubtitleStyle(position: position),
          ),
        ),
      );
      return tester.getTopLeft(find.text('Bonjour')).dy;
    }

    final atTop = await top(SubtitlePosition.top);
    final raised = await top(SubtitlePosition.raised);
    final bottom = await top(SubtitlePosition.bottom);

    expect(atTop, lessThan(100));
    expect(raised, lessThan(bottom));
  });

  testWidgets('les paramètres ouvrent l apparence des sous-titres', (
    tester,
  ) async {
    await _pump(tester, const SettingsScreen());

    expect(find.text('Moyenne, Blanc'), findsOneWidget);
    await _tapAndSettle(tester, 'Apparence des sous-titres');

    expect(find.text('Aperçu'), findsOneWidget);
    expect(find.text('On remonte avant la tempête.'), findsOneWidget);
  });

  testWidgets('un choix s enregistre et l aperçu le montre', (tester) async {
    final settings = await _pump(tester, const SubtitleAppearanceScreen());
    expect(_sample(tester).style?.color, const Color(0xFFFFFFFF));

    await _tapAndSettle(tester, 'Couleur du texte');
    await _tapAndSettle(tester, 'Jaune');

    expect(settings.current.subtitleStyle.color, SubtitleColor.yellow);
    expect(_sample(tester).style?.color, const Color(0xFFFFF06A));
    expect(tester.takeException(), isNull);
  });

  testWidgets('rétablir revient à l apparence d origine', (tester) async {
    final settings = await _pump(tester, const SubtitleAppearanceScreen());
    await settings.save(
      const AppSettings(subtitleStyle: SubtitleStyle(size: SubtitleSize.large)),
    );
    await tester.pump();

    await _tapAndSettle(tester, "Rétablir les réglages d'origine");

    expect(settings.current.subtitleStyle, const SubtitleStyle());
  });

  for (final language in AppLocalizations.supportedLocales) {
    testWidgets('l écran tient dans la fenêtre (${language.languageCode})', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1024, 768)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(_Settings()),
            deviceProfileProvider.overrideWithValue(_profile),
          ],
          child: WidgetsApp(
            color: const Color(0xFF000000),
            locale: language,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            home: const SubtitleAppearanceScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
