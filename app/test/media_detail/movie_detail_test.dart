import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/media_detail/screens/movie_detail_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

Movie _movie(int id, String tag) => Movie(
  id: id,
  title: 'Le Dernier Récif',
  rawTitle: '$tag - Le Dernier Récif',
  contentKey: 'x:m:$id',
  locator: DirectStream('http://s/$id.mkv'),
  languageTag: tag,
  year: 2025,
);

const String _overview = 'Un biologiste tente de sauver un récif condamné.';

final class _Catalog extends Fake implements CatalogRepository {
  final List<int> asked = [];

  @override
  Future<List<Movie>> moviesByTitleKeys(int sourceId, Set<String> keys) async =>
      [_movie(1, 'FR'), _movie(2, 'EN')];

  @override
  Future<TitleDetails> movieDetails(int sourceId, int movieId) async {
    asked.add(movieId);
    return movieId == 1
        ? const TitleDetails(
            overview: _overview,
            genre: 'Documentaire',
            runtime: Duration(minutes: 102),
          )
        : TitleDetails.none;
  }
}

Future<_Catalog> _open(
  WidgetTester tester, {
  String language = 'fr',
  Size size = const Size(1280, 720),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final catalog = _Catalog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(AppSettings(languageCode: language)),
        catalogRepositoryProvider.overrideWithValue(catalog),
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
        home: MovieDetailScreen(sourceId: 1, movie: _movie(1, 'FR')),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return catalog;
}

void main() {
  testWidgets('montre le résumé, le genre et la durée', (tester) async {
    await _open(tester);

    expect(find.text(_overview), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('Documentaire'), findsOneWidget);
    expect(find.text('1 h 42'), findsOneWidget);
  });

  testWidgets('change de résumé avec la version', (tester) async {
    final catalog = await _open(tester);

    await tester.tap(find.text('Version'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('Anglais'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(catalog.asked, [1, 2]);
    expect(find.text(_overview), findsNothing);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('tient dans l écran (${locale.languageCode})', (tester) async {
      await _open(tester, language: locale.languageCode);
      expect(tester.takeException(), isNull);
    });
  }
}
