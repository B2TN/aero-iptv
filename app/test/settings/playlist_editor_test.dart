import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/settings/playlist/playlist_editor_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

const PlaylistSource _source = PlaylistSource(
  id: 1,
  name: 'Essai',
  kind: SourceKind.xtream,
);

/// Index de la ligne « Mot de passe » : nom, type, serveur, utilisateur.
const int _passwordRow = 4;

final class _Vault implements CredentialStore {
  PlaylistCredentials? stored = const XtreamCredentials(
    serverUrl: 'http://s.example',
    username: 'jean',
    password: 'ancien',
  );

  /// Panne à simuler à chaque écriture.
  Failure? failure;

  String get password => (stored! as XtreamCredentials).password;

  @override
  Future<PlaylistCredentials?> read(int sourceId) async => stored;

  @override
  Future<void> write(int sourceId, PlaylistCredentials credentials) async {
    final error = failure;
    if (error != null) throw error;
    stored = credentials;
  }

  @override
  Future<void> delete(int sourceId) async => stored = null;
}

final class _Repository implements PlaylistRepository {
  _Repository(this._vault);

  final _Vault _vault;

  @override
  Stream<List<PlaylistSource>> watchSources() => Stream.value(const [_source]);

  @override
  Future<Result<PlaylistSource>> add({
    required String name,
    required PlaylistCredentials credentials,
    String? defaultCountryCode,
  }) async => const Ok(_source);

  @override
  Future<Result<void>> update(
    PlaylistSource source, {
    PlaylistCredentials? credentials,
  }) async {
    try {
      if (credentials != null) await _vault.write(source.id, credentials);
    } on Failure catch (failure) {
      return Err(failure);
    }
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(int sourceId) async => const Ok(null);
}

final class _Settings implements SettingsRepository {
  @override
  Stream<AppSettings> watch() => const Stream.empty();

  @override
  Future<void> save(AppSettings settings) async {}
}

final class _Importer implements CatalogImporter {
  final List<PlaylistCredentials> received = [];

  @override
  Stream<ImportProgress> run(
    PlaylistSource source,
    PlaylistCredentials credentials,
  ) {
    received.add(credentials);
    return const Stream.empty();
  }
}

Future<void> _pumpEditor(
  WidgetTester tester,
  _Vault vault,
  _Importer importer, {
  String language = 'fr',
  Size window = const Size(1920, 1080),
}) async {
  tester.view
    ..physicalSize = window
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        settingsRepositoryProvider.overrideWithValue(_Settings()),
        credentialStoreProvider.overrideWithValue(vault),
        playlistRepositoryProvider.overrideWithValue(_Repository(vault)),
        importPlaylistProvider.overrideWithValue(
          ImportPlaylist(vault, importer),
        ),
      ],
      child: WidgetsApp(
        navigatorKey: navigator,
        color: const Color(0xFF000000),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        shortcuts: dpadShortcuts,
        home: const SizedBox.shrink(),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
      ),
    ),
  );
  unawaited(
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => const PlaylistEditorScreen(source: _source),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> _openPassword(WidgetTester tester) async {
  for (var i = 0; i < _passwordRow; i++) {
    await tester.sendKeyEvent(
      LogicalKeyboardKey.arrowDown,
      platform: 'android',
    );
    await tester.pump();
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.select, platform: 'android');
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String text) async {
  for (final letter in text.split('')) {
    final key = LogicalKeyboardKey.findKeyByKeyId(
      LogicalKeyboardKey.keyA.keyId + letter.codeUnitAt(0) - 'a'.codeUnitAt(0),
    )!;
    await tester.sendKeyDownEvent(key, platform: 'android', character: letter);
    await tester.sendKeyUpEvent(key, platform: 'android');
  }
  await tester.pump();
}

Future<void> _press(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final language in AppLocalizations.supportedLocales) {
    for (final window in const [Size(1920, 1080), Size(1024, 768)]) {
      final code = language.languageCode;
      testWidgets('les boutons restent dans leur rangée ($code, $window)', (
        tester,
      ) async {
        await _pumpEditor(
          tester,
          _Vault(),
          _Importer(),
          language: code,
          window: window,
        );

        // Un débordement ferait échouer ce test : le bouton hors de sa rangée
        // serait affiché, mais ne recevrait plus aucun clic.
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Enregistrer reçoit le clic sur une playlist existante', (
    tester,
  ) async {
    final vault = _Vault();
    await _pumpEditor(tester, vault, _Importer());

    await _openPassword(tester);
    await _type(tester, 'nouveau');
    await _press(tester, 'Valider');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump();

    expect(vault.password, 'nouveau');
  });

  testWidgets('Actualiser enregistre ce qui vient d être saisi', (
    tester,
  ) async {
    final vault = _Vault();
    final importer = _Importer();
    await _pumpEditor(tester, vault, importer);

    await _openPassword(tester);
    await _type(tester, 'nouveau');
    await _press(tester, 'Valider');
    await _press(tester, 'Actualiser');

    expect(vault.password, 'nouveau');
    expect(importer.received, hasLength(1));
    expect((importer.received.single as XtreamCredentials).password, 'nouveau');
  });

  testWidgets('un coffre en panne se dit, et rien n est actualisé', (
    tester,
  ) async {
    final vault = _Vault()
      ..failure = const VaultFailure('x', cause: 'ProviderException');
    final importer = _Importer();
    await _pumpEditor(tester, vault, importer);

    await _press(tester, 'Actualiser');

    expect(find.textContaining('ProviderException'), findsOneWidget);
    expect(importer.received, isEmpty);
    expect(find.byType(PlaylistEditorScreen), findsOneWidget);
  });

  testWidgets('un champ masqué repart de zéro', (tester) async {
    final vault = _Vault();
    await _pumpEditor(tester, vault, _Importer());

    await _openPassword(tester);
    await _type(tester, 'nouveau');
    await _press(tester, 'Valider');
    await _press(tester, 'Enregistrer');

    expect(vault.password, 'nouveau');
  });

  testWidgets('valider un champ masqué vide garde le mot de passe', (
    tester,
  ) async {
    final vault = _Vault();
    await _pumpEditor(tester, vault, _Importer());

    await _openPassword(tester);
    await _press(tester, 'Valider');
    await _press(tester, 'Actualiser');

    expect(vault.password, 'ancien');
  });

  testWidgets('Afficher révèle le texte d un champ masqué', (tester) async {
    await _pumpEditor(tester, _Vault(), _Importer());

    await _openPassword(tester);
    await _type(tester, 'nouveau');
    expect(find.text('•••••••|'), findsOneWidget);

    await _press(tester, 'Afficher');
    expect(find.text('nouveau|'), findsOneWidget);

    await _press(tester, 'Masquer');
    expect(find.text('•••••••|'), findsOneWidget);
  });
}
