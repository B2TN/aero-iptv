import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/home/screens/home_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

const PlaylistSource _source = PlaylistSource(
  id: 1,
  name: 'Essai',
  kind: SourceKind.xtream,
);

const Series _abysses = Series(
  id: 7,
  title: 'Abysses',
  groupingKey: 'abysses',
  versionCount: 1,
);

const Series _portRoyal = Series(
  id: 8,
  title: 'Port Royal',
  groupingKey: 'port royal',
  versionCount: 1,
);

const Movie _dune = Movie(
  id: 1,
  title: 'Dune',
  rawTitle: 'FR - Dune',
  contentKey: 'x:m:1',
  locator: DirectStream('http://s/1.mkv'),
  languageTag: 'FR',
);

Favorite _favorite(ContentKind kind, String key, int minute) => Favorite(
  sourceId: 1,
  kind: kind,
  key: key,
  title: key,
  addedAt: DateTime.utc(2026, 11, 18, 20, minute),
);

final class _Catalog extends Fake implements CatalogRepository {
  @override
  Future<List<Movie>> moviesByTitleKeys(int sourceId, Set<String> keys) async =>
      [if (keys.contains(GroupingKey.of('Dune'))) _dune];

  @override
  Future<List<Series>> seriesByGroupingKeys(
    int sourceId,
    List<String> groupingKeys, {
    required String language,
  }) async => [if (groupingKeys.contains('abysses')) _abysses];
}

final class _Favorites implements FavoritesRepository {
  _Favorites(this.items);

  final List<Favorite> items;

  @override
  Stream<List<Favorite>> watch(int sourceId) => Stream.value(items);

  @override
  Future<void> add(Favorite favorite) async {}

  @override
  Future<void> remove(int sourceId, ContentKind kind, String key) async {}
}

Future<void> _pump(WidgetTester tester, List<Favorite> favorites) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        sourcesProvider.overrideWith((ref) => Stream.value(const [_source])),
        homeFeedProvider.overrideWith(
          (ref) async => const HomeFeed(
            hero: [],
            continueWatching: [],
            series: [_portRoyal],
            movies: [],
          ),
        ),
        catalogRepositoryProvider.overrideWithValue(_Catalog()),
        favoritesRepositoryProvider.overrideWithValue(_Favorites(favorites)),
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
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'la rangée Favoris montre films et séries, au-dessus des autres',
    (tester) async {
      await _pump(tester, [
        _favorite(ContentKind.series, 'abysses', 2),
        _favorite(ContentKind.movie, GroupingKey.of('Dune'), 1),
        // Plus dans le catalogue : il reste en favori sans s'afficher.
        _favorite(ContentKind.movie, 'disparu', 0),
      ]);

      expect(find.text('Favoris'), findsOneWidget);
      final abysses = tester.getTopLeft(find.text('Abysses').last);
      final dune = tester.getTopLeft(find.text('Dune').last);
      expect(abysses.dy, dune.dy);
      expect(abysses.dx, lessThan(dune.dx));
      expect(
        tester.getTopLeft(find.text('Port Royal').last).dy,
        greaterThan(abysses.dy),
      );
    },
  );

  testWidgets('sans favori, pas de rangée', (tester) async {
    await _pump(tester, const []);

    expect(find.text('Favoris'), findsNothing);
    // Sans affiche, la carte écrit aussi le titre dans son image.
    expect(find.text('Port Royal'), findsWidgets);
  });
}
