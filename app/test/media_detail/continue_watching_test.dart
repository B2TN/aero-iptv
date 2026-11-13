import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/media_detail/open_continued.dart';
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

const Movie _movie = Movie(
  id: 1,
  title: 'Lagon',
  rawTitle: 'FR - Lagon',
  contentKey: 'x:m:1',
  locator: DirectStream('http://s/1.mkv'),
  languageTag: 'FR',
);

const Series _series = Series(
  id: 7,
  title: 'Abysses',
  groupingKey: 'abysses',
  versionCount: 1,
);

Episode _episode(int season, int number) => Episode(
  id: season * 100 + number,
  seriesEntryId: 7,
  season: season,
  number: number,
  title: 'Épisode $number',
  contentKey: 'x:e:$season$number',
  locator: DirectStream('http://s/e$season$number.mkv'),
);

WatchProgress _progress(ContentKind kind, String key) => WatchProgress(
  sourceId: 1,
  contentKey: key,
  kind: kind,
  title: 'Titre',
  position: const Duration(minutes: 21),
  duration: const Duration(minutes: 45),
  updatedAt: DateTime.utc(2026, 11, 13),
  locator: const DirectStream('http://s/reprise.mkv'),
);

final class _Catalog extends Fake implements CatalogRepository {
  _Catalog({this.knowsContent = true});

  final bool knowsContent;

  @override
  Future<Movie?> movieByContentKey(int sourceId, String contentKey) async =>
      knowsContent ? _movie : null;

  @override
  Future<List<Movie>> moviesByTitleKeys(int sourceId, Set<String> keys) async =>
      const [_movie];

  @override
  Future<(Series, Episode)?> episodeByContentKey(
    int sourceId,
    String contentKey,
  ) async => knowsContent ? (_series, _episode(2, 3)) : null;

  @override
  Future<List<Season>> seasonsOf(int sourceId, int seriesEntryId) async => [
    Season(number: 1, episodes: [_episode(1, 1), _episode(1, 2)]),
    Season(
      number: 2,
      episodes: [_episode(2, 1), _episode(2, 2), _episode(2, 3)],
    ),
  ];

  @override
  Future<String?> tmdbIdOfEpisode(int sourceId, String contentKey) async =>
      null;

  @override
  Future<TitleDetails> movieDetails(int sourceId, int movieId) async =>
      TitleDetails.none;

  @override
  Future<TitleDetails> seriesDetails(int sourceId, int seriesEntryId) async =>
      TitleDetails.none;
}

/// Pas de calendrier : la fiche ne sort pas sur le réseau pendant le test.
final class _NoSchedule implements ScheduleRepository {
  @override
  Future<ShowSchedule?> scheduleOf(String title, {int? year}) async => null;
}

final class _Engine extends Fake implements PlaybackEngine {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();
  final List<PlaybackRequest> opened = [];

  @override
  PlaybackState get state => const PlaybackState();

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  Stream<String> get subtitleCues => const Stream.empty();

  @override
  Future<void> open(PlaybackRequest request) async => opened.add(request);

  @override
  Future<void> dispose() => _states.close();
}

final class _NoProgress extends Fake implements WatchProgressRepository {
  @override
  Future<void> save(WatchProgress progress) async {}
}

final class _NoCredentials extends Fake implements CredentialStore {}

Future<_Engine> _open(
  WidgetTester tester,
  WatchProgress item, {
  _Catalog? catalog,
}) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final engine = _Engine();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeSourceProvider.overrideWithValue(_source),
        settingsProvider.overrideWithValue(const AppSettings()),
        catalogRepositoryProvider.overrideWithValue(catalog ?? _Catalog()),
        scheduleRepositoryProvider.overrideWithValue(_NoSchedule()),
        playbackEngineFactoryProvider.overrideWithValue(() => engine),
        videoSurfaceBuilderProvider.overrideWithValue(
          (_) => const SizedBox.expand(),
        ),
        watchProgressRepositoryProvider.overrideWithValue(_NoProgress()),
        resolveStreamUrlProvider.overrideWithValue(
          ResolveStreamUrl(_NoCredentials()),
        ),
        findMediaSegmentsProvider.overrideWithValue(
          const FindMediaSegments(null),
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
            onTap: () => openContinued(context, ref, item),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return engine;
}

/// Ferme l'écran, ce qui annule les minuteries du lecteur.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 8));
}

void main() {
  group('film', () {
    testWidgets('ouvre la fiche, sans lancer la lecture', (tester) async {
      final engine = await _open(tester, _progress(ContentKind.movie, 'x:m:1'));

      expect(engine.opened, isEmpty);
      expect(find.text('Lagon'), findsOneWidget);
      expect(find.text('Reprendre'), findsOneWidget);
      expect(find.text('Lecture depuis le début'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('la fiche reprend à la position enregistrée', (tester) async {
      final engine = await _open(tester, _progress(ContentKind.movie, 'x:m:1'));

      await tester.tap(find.text('Reprendre'));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(engine.opened.single.startAt, const Duration(minutes: 21));
      await _leave(tester);
    });

    testWidgets('la fiche peut aussi repartir du début', (tester) async {
      final engine = await _open(tester, _progress(ContentKind.movie, 'x:m:1'));

      await tester.tap(find.text('Lecture depuis le début'));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(engine.opened.single.startAt, Duration.zero);
      await _leave(tester);
    });
  });

  group('série', () {
    testWidgets('ouvre la fiche sur la saison en cours', (tester) async {
      final engine = await _open(
        tester,
        _progress(ContentKind.series, 'x:e:23'),
      );

      expect(engine.opened, isEmpty);
      expect(find.text('Abysses'), findsOneWidget);
      expect(find.text('Saison 2, épisode 3'), findsOneWidget);
      expect(find.text('Reprendre'), findsOneWidget);
      // La saison 2 est affichée : son troisième épisode est dans la liste.
      expect(find.textContaining('Épisode 3'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('reprend l épisode à la position enregistrée', (tester) async {
      final engine = await _open(
        tester,
        _progress(ContentKind.series, 'x:e:23'),
      );

      await tester.tap(find.text('Reprendre'));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      final request = engine.opened.single;
      expect(request.stream.url, 'http://s/e23.mkv');
      expect(request.startAt, const Duration(minutes: 21));
      await _leave(tester);
    });
  });

  testWidgets('un contenu retiré du catalogue reprend directement', (
    tester,
  ) async {
    final engine = await _open(
      tester,
      _progress(ContentKind.movie, 'x:m:9'),
      catalog: _Catalog(knowsContent: false),
    );

    expect(engine.opened.single.stream.url, 'http://s/reprise.mkv');
    expect(engine.opened.single.startAt, const Duration(minutes: 21));
    await _leave(tester);
  });
}
