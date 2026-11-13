import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/app/platform/device_profile.dart';
import 'package:aero_iptv/design_system/components/aero_button.dart';
import 'package:aero_iptv/design_system/glass/glass_panel.dart';
import 'package:aero_iptv/design_system/tokens/aero_look.dart';
import 'package:aero_iptv/features/settings/screens/settings_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/iptv_player.dart' show MemoryTier;

DeviceProfile _device(MemoryTier tier) =>
    DeviceProfile(memoryTier: tier, isTv: true);

AeroLook _lookOf({required MemoryTier tier, bool? performanceMode}) {
  final container = ProviderContainer(
    overrides: [
      deviceProfileProvider.overrideWithValue(_device(tier)),
      settingsProvider.overrideWithValue(
        AppSettings(performanceMode: performanceMode),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(lookProvider);
}

/// Réglages en mémoire, qui publient chaque enregistrement.
final class _Settings implements SettingsRepository {
  _Settings(this.current);

  final StreamController<AppSettings> _changes =
      StreamController<AppSettings>.broadcast();
  AppSettings current;

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

Widget _app(Widget home, {AeroLook look = AeroLook.aero}) => WidgetsApp(
  color: const Color(0xFF000000),
  locale: const Locale('fr'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  shortcuts: dpadShortcuts,
  pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (context, _, _) => builder(context),
  ),
  builder: (context, child) =>
      AeroLookScope(look: look, child: child ?? const SizedBox.shrink()),
  home: home,
);

Future<_Settings> _openSettings(
  WidgetTester tester, {
  AppSettings initial = const AppSettings(),
  MemoryTier tier = MemoryTier.standard,
}) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = _Settings(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        deviceProfileProvider.overrideWithValue(_device(tier)),
        playlistRepositoryProvider.overrideWithValue(_NoSources()),
      ],
      child: _app(const SettingsScreen()),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
  return settings;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  group('choix de l apparence', () {
    test('un appareil à petite mémoire prend le mode Performance', () {
      expect(_lookOf(tier: MemoryTier.low), AeroLook.performance);
      expect(_lookOf(tier: MemoryTier.standard), AeroLook.aero);
    });

    test('le choix de l utilisateur passe avant l appareil', () {
      expect(
        _lookOf(tier: MemoryTier.standard, performanceMode: true),
        AeroLook.performance,
      );
      expect(
        _lookOf(tier: MemoryTier.low, performanceMode: false),
        AeroLook.aero,
      );
    });
  });

  group('verre', () {
    testWidgets('floute en mode Aero', (tester) async {
      await tester.pumpWidget(_app(const GlassPanel(child: Text('Verre'))));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('reste un aplat sans flou en mode Performance', (tester) async {
      await tester.pumpWidget(
        _app(
          const GlassPanel(child: Text('Verre')),
          look: AeroLook.performance,
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Verre'), findsOneWidget);
    });

    testWidgets('les boutons perdent leur ombre en mode Performance', (
      tester,
    ) async {
      List<BoxShadow>? shadowsOf(AeroLook look) {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(AeroButton),
                matching: find.byType(DecoratedBox),
              )
              .last,
        );
        return (box.decoration as BoxDecoration).boxShadow;
      }

      final button = AeroButton(label: 'Lire', onSelect: () {});
      await tester.pumpWidget(_app(button));
      expect(shadowsOf(AeroLook.aero), isNotEmpty);

      await tester.pumpWidget(_app(button, look: AeroLook.performance));
      expect(shadowsOf(AeroLook.performance), isNull);
    });
  });

  group('réglages', () {
    testWidgets(
      'le mode Performance suit l appareil tant que rien n est choisi',
      (tester) async {
        await _openSettings(tester, tier: MemoryTier.low);
        expect(find.text('Automatique (Activé)'), findsOneWidget);
      },
    );

    testWidgets('activer le mode Performance l enregistre', (tester) async {
      final settings = await _openSettings(tester);

      await _tap(tester, 'Mode Performance');

      expect(settings.current.performanceMode, isTrue);
    });

    testWidgets('le regroupement des films se désactive', (tester) async {
      final settings = await _openSettings(tester);
      expect(settings.current.groupMovies, isTrue);

      await _tap(tester, 'Regrouper les versions des films');

      expect(settings.current.groupMovies, isFalse);
    });
  });
}
