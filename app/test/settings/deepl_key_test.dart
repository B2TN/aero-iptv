import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/design_system/components/qr_sheet.dart';
import 'package:aero_iptv/features/settings/screens/settings_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:qr/qr.dart';

const String _keysPage = 'https://www.deepl.com/your-account/keys';

final Finder _qrCode = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is QrPainter,
);

Future<List<String>> _openEntry(
  WidgetTester tester, {
  required bool hasBrowser,
  String language = 'fr',
  String? row,
}) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(AppSettings(languageCode: language)),
        sourcesProvider.overrideWith(
          (ref) => Stream.value(const <PlaylistSource>[]),
        ),
        webPageOpenerProvider.overrideWithValue((url) async {
          opened.add(url);
          return hasBrowser;
        }),
      ],
      child: WidgetsApp(
        color: const Color(0xFF000000),
        locale: Locale(language),
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
  await tester.pump();
  final l10n = lookupAppLocalizations(Locale(language));
  await tester.tap(find.text(row ?? l10n.settingsDeepL));
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return opened;
}

void main() {
  testWidgets('le bouton se place à côté de Afficher', (tester) async {
    await _openEntry(tester, hasBrowser: true);

    final show = tester.getRect(find.text('Afficher'));
    final get = tester.getRect(find.text('Obtenir une clé'));
    final cancel = tester.getRect(find.text('Annuler'));
    expect(get.left, greaterThan(show.right));
    expect(get.right, lessThan(cancel.left));
    expect(get.center.dy, show.center.dy);
  });

  testWidgets('sur PC, ouvre la page DeepL', (tester) async {
    final opened = await _openEntry(tester, hasBrowser: true);

    await tester.tap(find.text('Obtenir une clé'));
    await tester.pump();
    await tester.pump();

    expect(opened, [_keysPage]);
    expect(_qrCode, findsNothing);
  });

  testWidgets('sans navigateur, propose un QR code de la page', (tester) async {
    await _openEntry(tester, hasBrowser: false);

    await tester.tap(find.text('Obtenir une clé'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final painter = tester.widget<CustomPaint>(_qrCode).painter! as QrPainter;
    expect(painter.data, _keysPage);
    expect(find.text(_keysPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Retour'));
    await tester.pump();
    await tester.pump();

    expect(find.text(_keysPage), findsNothing);
    expect(find.text('Obtenir une clé'), findsOneWidget);
  });

  for (final language in AppLocalizations.supportedLocales) {
    final code = language.languageCode;
    testWidgets('la rangée de boutons tient dans la fenêtre ($code)', (
      tester,
    ) async {
      await _openEntry(tester, hasBrowser: true, language: code);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('seule la clé DeepL est demandée', (tester) async {
    await _openEntry(tester, hasBrowser: true);

    // Les paramètres restent affichés sous la saisie.
    expect(find.text('Clé DeepL (sous-titres traduits)'), findsWidgets);
    expect(find.textContaining('OpenSubtitles'), findsNothing);
  });

  testWidgets('le QR code nomme le service', (tester) async {
    await _openEntry(tester, hasBrowser: false);

    await tester.tap(find.text('Obtenir une clé'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('la page DeepL'), findsOneWidget);
  });

  test('le code contient bien l adresse complète', () {
    final code = QrCode.fromData(
      data: _keysPage,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(code);
    expect(image.moduleCount, greaterThanOrEqualTo(21));
    // Les trois repères de coin sont noirs : le code est bien formé.
    expect(image.isDark(0, 0), isTrue);
    expect(image.isDark(0, image.moduleCount - 1), isTrue);
    expect(image.isDark(image.moduleCount - 1, 0), isTrue);
  });
}
