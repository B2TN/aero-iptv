import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/media_detail/title_menu.dart';
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

Movie _movie(int id, String tag) => Movie(
  id: id,
  title: 'Dune',
  rawTitle: '$tag - Dune',
  contentKey: 'x:m:$id',
  locator: DirectStream('http://s/$id.mkv'),
  languageTag: tag,
);

const Series _series = Series(
  id: 7,
  title: 'Abysses',
  groupingKey: 'abysses',
  versionCount: 1,
);

final Episode _episode = Episode(
  id: 71,
  seriesEntryId: 7,
  season: 1,
  number: 3,
  title: 'Abysses',
  contentKey: 'x:e:13',
  locator: const DirectStream('http://s/e13.mkv'),
);

WatchProgress _progress(String key, ContentKind kind) => WatchProgress(
  sourceId: 1,
  contentKey: key,
  kind: kind,
  seriesKey: kind == ContentKind.series ? 'abysses' : null,
  title: 'Reprise',
  position: const Duration(minutes: 20),
  duration: const Duration(minutes: 42),
  updatedAt: DateTime.utc(2026, 11, 18),
  locator: const DirectStream('http://s/reprise.mkv'),
);

final class _Catalog extends Fake implements CatalogRepository {
  _Catalog(this.versions);

  final List<Movie> versions;

  @override
  Future<List<Movie>> moviesByTitleKeys(int sourceId, Set<String> keys) async =>
      versions;

  @override
  Future<List<MediaVersion>> versionsOf(
    int sourceId,
    String groupingKey,
  ) async => const [
    MediaVersion(seriesEntryId: 7, label: 'FR', rawTitle: 'FR - Abysses'),
  ];

  @override
  Future<(Series, Episode)?> episodeByContentKey(
    int sourceId,
    String contentKey,
  ) async => contentKey == _episode.contentKey ? (_series, _episode) : null;

  @override
  Future<Movie?> movieByContentKey(int sourceId, String contentKey) async =>
      versions.where((movie) => movie.contentKey == contentKey).firstOrNull;
}

final class _Progress extends Fake implements WatchProgressRepository {
  _Progress(this.items);

  final List<WatchProgress> items;
  final List<String> removed = [];

  @override
  Future<List<WatchProgress>> continueWatching(
    int sourceId, {
    int limit = 20,
  }) async => items;

  @override
  Future<void> hide(int sourceId, String groupKey) async =>
      removed.add(groupKey);
}

/// Favoris en mémoire, publiés à chaque changement.
final class _Favorites implements FavoritesRepository {
  final List<Favorite> items = [];
  final StreamController<List<Favorite>> _changes =
      StreamController<List<Favorite>>.broadcast();

  @override
  Stream<List<Favorite>> watch(int sourceId) async* {
    yield List.of(items);
    yield* _changes.stream;
  }

  @override
  Future<void> add(Favorite favorite) async {
    items.add(favorite);
    _changes.add(List.of(items));
  }

  @override
  Future<void> remove(int sourceId, ContentKind kind, String key) async {
    items.removeWhere((item) => item.kind == kind && item.key == key);
    _changes.add(List.of(items));
  }
}

typedef _Menu = Future<void> Function(BuildContext context, WidgetRef ref);

Future<void> _open(
  WidgetTester tester,
  _Menu menu, {
  List<Movie> movies = const [],
  List<WatchProgress> progress = const [],
  _Favorites? favorites,
  _Progress? progressRepository,
}) async {
  tester.view
    ..physicalSize = const Size(1280, 720)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeSourceProvider.overrideWithValue(_source),
        settingsProvider.overrideWithValue(const AppSettings()),
        catalogRepositoryProvider.overrideWithValue(_Catalog(movies)),
        watchProgressRepositoryProvider.overrideWithValue(
          progressRepository ?? _Progress(progress),
        ),
        favoritesRepositoryProvider.overrideWithValue(
          favorites ?? _Favorites(),
        ),
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
        home: Consumer(
          builder: (context, ref, _) => GestureDetector(
            // Les favoris sont écoutés comme le fait l'accueil.
            onTap: () => menu(context, ref),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Ouvrir'));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> _choose(WidgetTester tester, String option) async {
  await tester.tap(find.text(option));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('le menu d un film propose fiche, lecture, version, favori', (
    tester,
  ) async {
    await _open(
      tester,
      (context, ref) => showMovieMenu(context, ref, _movie(1, 'FR')),
      movies: [_movie(1, 'FR'), _movie(2, 'EN')],
    );

    expect(find.text('Voir la fiche'), findsOneWidget);
    expect(find.text('Lire'), findsOneWidget);
    expect(find.text('Choisir la version'), findsOneWidget);
    expect(find.text('Ajouter aux favoris'), findsOneWidget);
  });

  testWidgets('un film commencé se reprend depuis le menu', (tester) async {
    await _open(
      tester,
      (context, ref) => showMovieMenu(context, ref, _movie(1, 'FR')),
      movies: [_movie(1, 'FR'), _movie(2, 'EN')],
      // La reprise porte sur l'autre version : elle compte aussi.
      progress: [_progress('x:m:2', ContentKind.movie)],
    );

    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Lire'), findsNothing);
  });

  testWidgets('une seule version : pas de choix de version', (tester) async {
    await _open(
      tester,
      (context, ref) => showMovieMenu(context, ref, _movie(1, 'FR')),
      movies: [_movie(1, 'FR')],
    );

    expect(find.text('Choisir la version'), findsNothing);
  });

  testWidgets('ajouter puis retirer un film des favoris', (tester) async {
    final favorites = _Favorites();
    await _open(
      tester,
      (context, ref) => showMovieMenu(context, ref, _movie(1, 'FR')),
      movies: [_movie(1, 'FR')],
      favorites: favorites,
    );

    await _choose(tester, 'Ajouter aux favoris');
    expect(favorites.items.single.key, GroupingKey.of('Dune'));
    expect(favorites.items.single.kind, ContentKind.movie);

    await tester.tap(find.text('Ouvrir'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    await _choose(tester, 'Retirer des favoris');
    expect(favorites.items, isEmpty);
  });

  testWidgets('une série commencée se reprend, même ouverte ailleurs', (
    tester,
  ) async {
    final favorites = _Favorites();
    await _open(
      tester,
      (context, ref) => showSeriesMenu(context, ref, _series),
      progress: [_progress(_episode.contentKey, ContentKind.series)],
      favorites: favorites,
    );

    expect(find.text('Voir la fiche'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
    await _choose(tester, 'Ajouter aux favoris');
    expect(favorites.items.single.key, 'abysses');
  });

  testWidgets('Continuer à regarder : fiche, favori et retrait', (
    tester,
  ) async {
    final repository = _Progress(const []);
    final item = _progress(_episode.contentKey, ContentKind.series);
    var removed = false;
    await _open(
      tester,
      (context, ref) =>
          showContinueMenu(context, ref, item, onRemoved: () => removed = true),
      progressRepository: repository,
    );

    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Voir la fiche'), findsOneWidget);
    expect(find.text('Ajouter aux favoris'), findsOneWidget);

    await _choose(tester, 'Supprimer de Continuer à regarder');
    // Toute la série sort de la rangée, pas seulement cet épisode.
    expect(repository.removed, ['abysses']);
    expect(removed, isTrue);
  });
}
