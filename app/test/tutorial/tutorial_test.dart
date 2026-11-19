import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/app/platform/api_key_store.dart';
import 'package:aero_iptv/app/platform/device_profile.dart';
import 'package:aero_iptv/features/tutorial/tutorial_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/iptv_player.dart' show MemoryTier;

const PlaylistSource _source = PlaylistSource(
  id: 1,
  name: 'Essai',
  kind: SourceKind.xtream,
);

final class _Settings implements SettingsRepository {
  _Settings([this.value = const AppSettings()]);

  AppSettings value;
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

final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

/// Ouvre le tutoriel par-dessus un écran d'accueil simulé.
Future<_Settings> _open(
  WidgetTester tester, {
  List<PlaylistSource> sources = const [_source],
  MemoryTier memory = MemoryTier.standard,
  String language = 'fr',
  Size size = const Size(1280, 720),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final settings = _Settings(AppSettings(languageCode: language));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settings),
        sourcesProvider.overrideWith((ref) => Stream.value(sources)),
        deviceProfileProvider.overrideWithValue(
          DeviceProfile(memoryTier: memory, isTv: true),
        ),
        apiKeyStoreProvider.overrideWithValue(const MemorylessApiKeyStore()),
      ],
      // La langue suit les réglages, comme dans l'application.
      child: Consumer(
        builder: (context, ref, _) {
          final language = ref.watch(settingsProvider).languageCode;
          return WidgetsApp(
            navigatorKey: _navigator,
            color: const Color(0xFF000000),
            locale: Locale(language),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            shortcuts: dpadShortcuts,
            actions: {
              ...WidgetsApp.defaultActions,
              BackIntent: CallbackAction<BackIntent>(
                onInvoke: (_) => _navigator.currentState?.maybePop(),
              ),
            },
            pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, _) => builder(context),
            ),
            home: const Text('Accueil'),
          );
        },
      ),
    ),
  );
  await _settle(tester);
  unawaited(openTutorial(_navigator.currentContext!));
  await _settle(tester);
  return settings;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await _settle(tester);
}

/// Avance de [steps] étapes avec « Suivant ».
Future<void> _forward(WidgetTester tester, int steps) async {
  for (var i = 0; i < steps; i++) {
    await _tap(tester, 'Suivant');
  }
}

String? get _focused => FocusManager.instance.primaryFocus?.debugLabel;

void main() {
  testWidgets('se parcourt en entier au D-pad, puis se ferme', (tester) async {
    final settings = await _open(tester);
    expect(find.text('Étape 1 sur 9'), findsOneWidget);
    expect(find.text('Bienvenue dans Aero IPTV'), findsOneWidget);
    expect(_focused, 'TutorialNext');

    for (var step = 2; step <= 9; step++) {
      await _press(tester, LogicalKeyboardKey.enter);
      expect(find.text('Étape $step sur 9'), findsOneWidget);
      // OK enchaîne les étapes : le focus reste sur « Suivant ».
      expect(_focused, 'TutorialNext');
    }
    expect(find.text('Synchronisation et mises à jour'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.enter);

    expect(find.byType(TutorialScreen), findsNothing);
    expect(find.text('Accueil'), findsOneWidget);
    expect(settings.value.tutorialDone, isTrue);
  });

  testWidgets('sans playlist, son étape met en avant l ajout', (tester) async {
    await _open(tester, sources: const []);

    await _press(tester, LogicalKeyboardKey.enter);

    expect(find.text('Ajoutez votre playlist'), findsOneWidget);
    expect(find.text('Aucune'), findsOneWidget);
    expect(_focused, 'TutorialAction');
    expect(find.text('Ajouter une playlist'), findsOneWidget);
  });

  testWidgets('Retour revient en arrière, et ferme depuis la première étape', (
    tester,
  ) async {
    final settings = await _open(tester);
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.enter);
    expect(find.text('Étape 3 sur 9'), findsOneWidget);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.text('Étape 2 sur 9'), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.text('Étape 1 sur 9'), findsOneWidget);
    expect(settings.value.tutorialDone, isFalse);

    await _press(tester, LogicalKeyboardKey.escape);

    expect(find.byType(TutorialScreen), findsNothing);
    expect(settings.value.tutorialDone, isTrue);
  });

  testWidgets('Passer le ferme à tout moment', (tester) async {
    final settings = await _open(tester);
    await _forward(tester, 4);

    await _tap(tester, 'Passer');

    expect(find.byType(TutorialScreen), findsNothing);
    expect(settings.value.tutorialDone, isTrue);
  });

  testWidgets('le mode Performance se règle depuis son étape', (tester) async {
    final settings = await _open(tester);
    await _forward(tester, 2);
    expect(find.text('Mode Performance'), findsWidgets);
    expect(
      find.textContaining('assez de mémoire pour garder les effets'),
      findsOneWidget,
    );
    expect(find.text('Automatique (Désactivé)'), findsOneWidget);

    await _tap(tester, 'Activer le mode Performance');

    expect(settings.value.performanceMode, isTrue);
    expect(find.text('Activé'), findsOneWidget);
    expect(find.text('Désactiver le mode Performance'), findsOneWidget);
  });

  testWidgets('sur un petit appareil, le mode Performance est conseillé', (
    tester,
  ) async {
    await _open(tester, memory: MemoryTier.low);
    await _forward(tester, 2);

    expect(find.textContaining('peu de mémoire'), findsOneWidget);
    expect(find.text('Automatique (Activé)'), findsOneWidget);
  });

  testWidgets('la langue choisie s applique aussitôt', (tester) async {
    final settings = await _open(tester);

    await _tap(tester, 'Changer la langue');
    await _tap(tester, 'English');

    expect(settings.value.languageCode, 'en');
    expect(find.text('Welcome to Aero IPTV'), findsOneWidget);
    expect(find.text('Step 1 of 9'), findsOneWidget);
  });

  testWidgets('la clé DeepL se saisit depuis l étape du lecteur', (
    tester,
  ) async {
    await _open(tester);
    await _forward(tester, 7);
    expect(find.text('Lecteur et sous-titres'), findsOneWidget);
    expect(find.text('Non configurée'), findsOneWidget);

    await _tap(tester, 'Ajouter une clé DeepL');

    // La saisie des Paramètres, avec son lien vers la page de DeepL.
    expect(find.text('Obtenir une clé'), findsOneWidget);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
      testWidgets('chaque étape tient dans l écran '
          '(${locale.languageCode}, $size)', (tester) async {
        await _open(
          tester,
          language: locale.languageCode,
          size: size,
          memory: MemoryTier.low,
        );
        // Un débordement ferait échouer le test.
        for (var step = 2; step <= 9; step++) {
          await _press(tester, LogicalKeyboardKey.enter);
        }
        expect(find.byType(TutorialScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('premier lancement', () {
    ProviderContainer container({
      required List<PlaylistSource> sources,
      bool done = false,
    }) {
      final result = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            _Settings(AppSettings(tutorialDone: done)),
          ),
          sourcesProvider.overrideWith((ref) => Stream.value(sources)),
        ],
      );
      addTearDown(result.dispose);
      result.listen(tutorialDueProvider, (_, _) {});
      return result;
    }

    test('une installation neuve voit le tutoriel', () async {
      final fresh = container(sources: const []);
      expect(fresh.read(tutorialDueProvider), isNull);

      await pumpEventQueue();

      expect(fresh.read(tutorialDueProvider), isTrue);
    });

    test('une installation déjà configurée ne le voit pas', () async {
      final configured = container(sources: const [_source]);
      await pumpEventQueue();

      expect(configured.read(tutorialDueProvider), isFalse);
    });

    test('un tutoriel vu ne revient pas', () async {
      final seen = container(sources: const [], done: true);
      await pumpEventQueue();

      expect(seen.read(tutorialDueProvider), isFalse);
    });
  });
}
