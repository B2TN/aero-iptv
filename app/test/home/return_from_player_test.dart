import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/design_system/components/poster_card.dart';
import 'package:aero_iptv/design_system/components/progress_track.dart';
import 'package:aero_iptv/features/home/screens/home_screen.dart';
import 'package:aero_iptv/features/home/widgets/continue_card.dart';
import 'package:aero_iptv/features/media_detail/screens/movie_detail_screen.dart';
import 'package:aero_iptv/features/player/player_target.dart';
import 'package:aero_iptv/focus/dpad_collection.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

const PlaylistSource _source = PlaylistSource(
  id: 1,
  name: 'Essai',
  kind: SourceKind.xtream,
);

Movie _movie(int id, String title) => Movie(
  id: id,
  title: title,
  rawTitle: 'FR - $title',
  contentKey: 'x:m:$id',
  locator: DirectStream('http://s/$id.mkv'),
  languageTag: 'FR',
);

final Movie _lagon = _movie(1, 'Lagon');
final Movie _recif = _movie(2, 'Récif');

Series _series(int id) => Series(
  id: id,
  title: 'Série $id',
  groupingKey: 'serie $id',
  versionCount: 1,
);

WatchProgress _progress(
  Movie movie, {
  required int minutes,
  required int day,
}) => WatchProgress(
  sourceId: 1,
  contentKey: movie.contentKey,
  kind: ContentKind.movie,
  title: movie.title,
  position: Duration(minutes: minutes),
  duration: const Duration(minutes: 45),
  updatedAt: DateTime.utc(2026, 11, day),
  locator: movie.locator,
  workKey: WorkKeys.movie(movie.groupingKey),
);

final class _Catalog extends Fake implements CatalogRepository {
  _Catalog({this.movieList = const [], this.seriesList = const []});

  final List<Movie> movieList;
  final List<Series> seriesList;

  @override
  Future<Page<Movie>> movies(int sourceId, PageRequest page) async =>
      Page(items: movieList, request: page);

  @override
  Future<List<Movie>> moviesInLanguage(
    int sourceId,
    String language,
    PageRequest page,
  ) async => movieList;

  @override
  Future<Page<Series>> series(
    int sourceId,
    PageRequest page, {
    required bool grouped,
    required String language,
  }) async => Page(items: seriesList, request: page);

  @override
  Future<Movie?> movieByContentKey(int sourceId, String contentKey) async =>
      movieList.where((movie) => movie.contentKey == contentKey).firstOrNull;

  @override
  Future<List<Movie>> moviesByGroupingKeys(
    int sourceId,
    Set<String> groupingKeys,
  ) async => [
    for (final movie in movieList)
      if (groupingKeys.contains(movie.groupingKey)) movie,
  ];

  @override
  Future<TitleDetails> movieDetails(int sourceId, int movieId) async =>
      TitleDetails.none;
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

/// Positions de lecture en mémoire, la plus récente d'abord.
final class _Progress implements WatchProgressRepository {
  _Progress([Iterable<WatchProgress> items = const []]) {
    for (final item in items) {
      _items[item.contentKey] = item;
    }
  }

  final Map<String, WatchProgress> _items = {};

  List<WatchProgress> get _recent =>
      _items.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> save(WatchProgress progress) async =>
      _items[progress.contentKey] = progress;

  @override
  Future<List<WatchProgress>> history(int sourceId, {int limit = 500}) async =>
      _recent.take(limit).toList();

  @override
  Future<List<WatchProgress>> progressOf(int sourceId, String key) async => [
    for (final item in _recent)
      if (item.workKey == key || item.seriesKey == key) item,
  ];

  @override
  Future<List<WatchProgress>> continueWatching(
    int sourceId, {
    int limit = 20,
  }) async => _recent.take(limit).toList();

  @override
  Future<void> hide(int sourceId, String groupKey) async {}

  @override
  Future<void> remove(int sourceId, String contentKey) async =>
      _items.remove(contentKey);
}

final class _NoCredentials implements CredentialStore {
  @override
  Future<PlaylistCredentials?> read(int sourceId) async => null;

  @override
  Future<void> write(int sourceId, PlaylistCredentials credentials) async {}

  @override
  Future<void> delete(int sourceId) async {}
}

/// Moteur dont la libération n'aboutit pas, comme libmpv qui attend un
/// serveur lent avant de fermer le flux.
final class _SlowEngine implements PlaybackEngine {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  @override
  PlaybackState state = const PlaybackState();

  @override
  Stream<PlaybackState> get states => _states.stream;

  void emit(PlaybackState next) {
    state = next;
    _states.add(next);
  }

  @override
  Future<void> open(PlaybackRequest request) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Stream<String> get subtitleCues => const Stream.empty();

  @override
  Future<void> setVolume(double percent) async {}

  @override
  Future<void> selectAudio(MediaTrack track) async {}

  @override
  Future<void> selectSubtitle(MediaTrack? track) async {}

  @override
  Future<List<MediaChapter>> chapters() async => const [];

  @override
  Future<void> dispose() => Completer<void>().future;
}

final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

Future<_SlowEngine> _pump(
  WidgetTester tester, {
  required Widget home,
  required _Catalog catalog,
  required _Progress progress,
}) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final engine = _SlowEngine();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        sourcesProvider.overrideWith((ref) => Stream.value(const [_source])),
        catalogRepositoryProvider.overrideWithValue(catalog),
        trendingRepositoryProvider.overrideWithValue(_NoTrending()),
        favoritesRepositoryProvider.overrideWithValue(_NoFavorites()),
        watchProgressRepositoryProvider.overrideWithValue(progress),
        playbackEngineFactoryProvider.overrideWithValue(() => engine),
        videoSurfaceBuilderProvider.overrideWithValue(
          (_) => const SizedBox.expand(),
        ),
        resolveStreamUrlProvider.overrideWithValue(
          ResolveStreamUrl(_NoCredentials()),
        ),
        findMediaSegmentsProvider.overrideWithValue(
          const FindMediaSegments(null),
        ),
        subtitleTranslatorProvider.overrideWithValue(null),
      ],
      child: WidgetsApp(
        navigatorKey: _navigator,
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
  await _settle(tester);
  return engine;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

/// Lit jusqu'à 30 minutes sur 45, puis revient à l'écran précédent.
Future<void> _watch(
  WidgetTester tester,
  _SlowEngine engine,
  PlayerTarget? target,
) async {
  if (target != null) {
    unawaited(_navigator.currentState!.push(playerRoute(target)));
  }
  await _settle(tester);
  engine.emit(
    const PlaybackState(
      status: PlaybackStatus.playing,
      position: Duration(minutes: 30),
      duration: Duration(minutes: 45),
    ),
  );
  await _settle(tester);
  _navigator.currentState!.pop();
  await _settle(tester);
}

/// Donne le focus à la rangée [memoryKey] de l'accueil.
Future<void> _focusRow(WidgetTester tester, String memoryKey) async {
  final row = find.byWidgetPredicate(
    (widget) => widget is DpadCollection && widget.memoryKey == memoryKey,
  );
  tester
      .widget<Focus>(
        find.descendant(of: row, matching: find.byType(Focus)).first,
      )
      .focusNode!
      .requestFocus();
  await _settle(tester);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

List<String> _continueTitles(WidgetTester tester) => [
  for (final card in tester.widgetList<ContinueCard>(find.byType(ContinueCard)))
    card.item.title,
];

List<String> _focusedCards(WidgetTester tester) => [
  for (final card in tester.widgetList<ContinueCard>(find.byType(ContinueCard)))
    if (card.focused) card.item.title,
  for (final card in tester.widgetList<PosterCard>(find.byType(PosterCard)))
    if (card.focused) card.title,
];

/// Ferme l'écran, ce qui annule les minuteries du lecteur et du carrousel.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  testWidgets('au retour du lecteur, « Continuer à regarder » est à jour et '
      'garde le titre actif', (tester) async {
    final progress = _Progress([
      _progress(_lagon, minutes: 21, day: 13),
      _progress(_recif, minutes: 5, day: 12),
    ]);
    final engine = await _pump(
      tester,
      home: const HomeScreen(),
      catalog: _Catalog(movieList: [_lagon, _recif]),
      progress: progress,
    );
    expect(_continueTitles(tester), ['Lagon', 'Récif']);
    await _focusRow(tester, 'home.continue');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedCards(tester), ['Récif']);

    final recif = (await progress.history(1))[1];
    await _watch(tester, engine, PlayerTarget.resume(recif));

    // Sans attendre la libération du moteur : le dernier titre regardé passe
    // en tête, avec son nouveau temps.
    expect(_continueTitles(tester), ['Récif', 'Lagon']);
    expect(find.text('30:00 / 45:00'), findsOneWidget);
    // Le focus suit le titre regardé.
    expect(_focusedCards(tester), ['Récif']);
    await _leave(tester);
  });

  testWidgets('une rangée « Continuer à regarder » qui apparaît ne déplace '
      'pas le focus', (tester) async {
    final engine = await _pump(
      tester,
      home: const HomeScreen(),
      catalog: _Catalog(
        movieList: [_lagon],
        seriesList: [for (var id = 1; id <= 6; id++) _series(id)],
      ),
      progress: _Progress(),
    );
    expect(find.byType(ContinueCard), findsNothing);
    await _focusRow(tester, 'home.series');
    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedCards(tester), ['Série 3']);

    await _watch(tester, engine, PlayerTarget.movie(1, _lagon));

    expect(_continueTitles(tester), ['Lagon']);
    expect(_focusedCards(tester), ['Série 3']);
    await _leave(tester);
  });

  testWidgets('au retour du lecteur, la fiche du film propose la reprise', (
    tester,
  ) async {
    final engine = await _pump(
      tester,
      home: MovieDetailScreen(sourceId: 1, movie: _lagon),
      catalog: _Catalog(movieList: [_lagon]),
      progress: _Progress(),
    );
    expect(find.text('Reprendre'), findsNothing);
    expect(find.byType(ProgressTrack), findsNothing);

    await tester.tap(find.text('Lecture'));
    await _watch(tester, engine, null);

    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.byType(ProgressTrack), findsOneWidget);
    await _leave(tester);
  });
}
