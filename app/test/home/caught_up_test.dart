import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/daily_sync.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/home/screens/home_screen.dart';
import 'package:aero_iptv/features/home/widgets/continue_card.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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

Episode _episode(int number) => Episode(
  id: 700 + number,
  seriesEntryId: 7,
  season: 1,
  number: number,
  title: 'Abysses',
  contentKey: 'x:e:1$number',
  locator: DirectStream('http://s/e1$number.mkv'),
);

final DateTime _now = DateTime(2026, 11, 20, 20);

/// Le dernier épisode de la playlist, vu jusqu'au bout, juste avant le film.
final WatchProgress _lastEpisode = WatchProgress(
  sourceId: 1,
  contentKey: 'x:e:12',
  kind: ContentKind.series,
  title: 'Abysses',
  position: const Duration(minutes: 42),
  duration: const Duration(minutes: 42),
  updatedAt: DateTime(2026, 11, 20, 19),
  locator: const DirectStream('http://s/e12.mkv'),
  workKey: WorkKeys.episode('abysses', 1, 2),
  seriesKey: 'abysses',
  season: 1,
  episode: 2,
  finished: true,
);

final WatchProgress _movie = WatchProgress(
  sourceId: 1,
  contentKey: 'x:m:1',
  kind: ContentKind.movie,
  title: 'Lagon',
  position: const Duration(minutes: 10),
  duration: const Duration(minutes: 90),
  updatedAt: DateTime(2026, 11, 20, 18),
  locator: const DirectStream('http://s/1.mkv'),
  workKey: WorkKeys.movie('lagon'),
);

final class _Catalog extends Fake implements CatalogRepository {
  @override
  Future<(Series, Episode)?> episodeByContentKey(
    int sourceId,
    String contentKey,
  ) async => contentKey.startsWith('x:e:1')
      ? (_abysses, _episode(int.parse(contentKey.substring(5))))
      : null;

  @override
  Future<List<Season>> seasonsOf(int sourceId, int seriesEntryId) async => [
    Season(number: 1, episodes: [_episode(1), _episode(2)]),
  ];

  @override
  Future<Movie?> movieByContentKey(int sourceId, String contentKey) async =>
      null;

  @override
  Future<List<MediaVersion>> versionsOf(
    int sourceId,
    String groupingKey,
  ) async => const [];

  @override
  Future<Page<Movie>> movies(int sourceId, PageRequest page) async =>
      Page(items: const [], request: page);

  @override
  Future<List<Movie>> moviesInLanguage(
    int sourceId,
    String language,
    PageRequest page,
  ) async => const [];

  @override
  Future<Page<Series>> series(
    int sourceId,
    PageRequest page, {
    required bool grouped,
    required String language,
  }) async => Page(items: const [_abysses], request: page);
}

final class _History extends Fake implements WatchProgressRepository {
  @override
  Future<List<WatchProgress>> history(int sourceId, {int limit = 500}) async =>
      [_lastEpisode, _movie];
}

final class _Schedule implements ScheduleRepository {
  _Schedule(this.schedule);

  final ShowSchedule? schedule;

  @override
  Future<ShowSchedule?> scheduleOf(String title, {int? year}) async => schedule;
}

final class _NoTrending implements TrendingRepository {
  @override
  bool get isAvailable => false;

  @override
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    String? region,
  }) async => const [];

  @override
  Future<DateTime?> refreshedAt(String region) async => null;

  @override
  Future<void> refresh(String region, {required String language}) async {}
}

final class _NoFavorites implements FavoritesRepository {
  @override
  Stream<List<Favorite>> watch(int sourceId) => Stream.value(const []);

  @override
  Future<void> add(Favorite favorite) async {}

  @override
  Future<void> remove(int sourceId, ContentKind kind, String key) async {}
}

Future<void> _pump(WidgetTester tester, ShowSchedule? schedule) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        sourcesProvider.overrideWith((ref) => Stream.value(const [_source])),
        catalogRepositoryProvider.overrideWithValue(_Catalog()),
        trendingRepositoryProvider.overrideWithValue(_NoTrending()),
        favoritesRepositoryProvider.overrideWithValue(_NoFavorites()),
        watchProgressRepositoryProvider.overrideWithValue(_History()),
        scheduleRepositoryProvider.overrideWithValue(_Schedule(schedule)),
        clockProvider.overrideWithValue(() => _now),
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
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

List<String> _titles(WidgetTester tester) => [
  for (final card in tester.widgetList<ContinueCard>(find.byType(ContinueCard)))
    card.item.title,
];

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  testWidgets('une série à jour dont la suite est annoncée reste, en dernier', (
    tester,
  ) async {
    await _pump(
      tester,
      ShowSchedule(
        running: true,
        upcoming: [
          UpcomingEpisode(
            season: 1,
            number: 3,
            airDate: DateTime(2026, 11, 24),
          ),
        ],
      ),
    );

    // Regardée après le film, elle passe pourtant après lui.
    expect(_titles(tester), ['Lagon', 'Abysses']);
    expect(find.text('Prochain épisode dans 4 jours'), findsOneWidget);
    final card = tester
        .widgetList<ContinueCard>(find.byType(ContinueCard))
        .last;
    expect(card.next?.number, 3);
    await _leave(tester);
  });

  testWidgets('une série terminée disparaît', (tester) async {
    await _pump(tester, const ShowSchedule(running: false));

    expect(_titles(tester), ['Lagon']);
    await _leave(tester);
  });

  group('mention du prochain épisode', () {
    final l10n = lookupAppLocalizations(const Locale('fr'));
    String label(DateTime airDate) => nextEpisodeLabel(l10n, airDate, _now);

    // L'application les charge avec ses traductions.
    setUpAll(() => initializeDateFormatting('fr'));

    test('en jours, puis à sa date', () {
      expect(label(DateTime(2026, 11, 20)), 'Prochain épisode aujourd\'hui');
      expect(label(DateTime(2026, 11, 21)), 'Prochain épisode demain');
      expect(label(DateTime(2026, 12, 2)), 'Prochain épisode dans 12 jours');
      expect(label(DateTime(2027, 1, 15)), 'Prochain épisode le 15 janvier');
    });

    test('déjà diffusé, il est attendu dans la playlist', () {
      expect(
        label(DateTime(2026, 11, 18)),
        'Épisode diffusé, bientôt dans la playlist',
      );
    });
  });
}
