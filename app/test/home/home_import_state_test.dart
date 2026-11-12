import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/features/home/screens/home_screen.dart';
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

const HomeFeed _emptyFeed = HomeFeed(
  hero: [],
  continueWatching: [],
  series: [],
  movies: [],
);

/// Import figé dans un état donné, qui note les relances demandées.
class _Import extends ImportController {
  _Import(this._status);

  final ImportStatus _status;
  final List<PlaylistSource> started = [];

  @override
  ImportStatus build() => _status;

  @override
  void start(PlaylistSource source) => started.add(source);
}

Future<_Import> _pump(WidgetTester tester, ImportStatus status) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final import = _Import(status);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        sourcesProvider.overrideWith((ref) => Stream.value(const [_source])),
        homeFeedProvider.overrideWith((ref) async => _emptyFeed),
        importControllerProvider.overrideWith(() => import),
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
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return import;
}

void main() {
  testWidgets('pendant l import, l accueil dit où il en est', (tester) async {
    await _pump(
      tester,
      const ImportStatus(
        running: true,
        stage: ImportStage.catalog,
        section: ContentKind.movie,
        processed: 4500,
      ),
    );

    expect(find.textContaining('Réception des films'), findsOneWidget);
    expect(find.textContaining('4500'), findsOneWidget);
    expect(find.text('Cette playlist est encore vide'), findsNothing);
  });

  testWidgets('un échec s affiche avec sa cause et un bouton', (tester) async {
    final import = await _pump(
      tester,
      const ImportStatus(failure: ServerFailure('x', status: 503)),
    );

    expect(find.text("L'actualisation a échoué"), findsOneWidget);
    expect(find.textContaining('503'), findsOneWidget);
    expect(find.text('Cette playlist est encore vide'), findsNothing);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();

    expect(import.started, [_source]);
  });

  testWidgets('un échec imprévu se nomme et dit son étape', (tester) async {
    await _pump(
      tester,
      const ImportStatus(
        failure: StorageFailure('x', code: 6410),
        stage: ImportStage.indexing,
        processed: 9000,
      ),
    );

    expect(find.textContaining('6410'), findsOneWidget);
    expect(find.textContaining('Dernière étape'), findsOneWidget);
    expect(find.textContaining('Préparation du catalogue'), findsOneWidget);
    expect(find.textContaining('stockage, puis'), findsNothing);
  });

  testWidgets('le bouton de relance a le focus de la télécommande', (
    tester,
  ) async {
    final import = await _pump(
      tester,
      const ImportStatus(failure: NetworkFailure('x')),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(import.started, hasLength(1));
  });

  testWidgets('sans import, la playlist vide renvoie aux paramètres', (
    tester,
  ) async {
    await _pump(tester, const ImportStatus());

    expect(find.text('Cette playlist est encore vide'), findsOneWidget);
    expect(find.text('Ouvrir les paramètres'), findsOneWidget);
  });
}
