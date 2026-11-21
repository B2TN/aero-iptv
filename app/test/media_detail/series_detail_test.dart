import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/design_system/components/progress_track.dart';
import 'package:aero_iptv/features/media_detail/screens/media_detail_screen.dart';
import 'package:aero_iptv/features/media_detail/widgets/episode_lines.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/focus/focus_frame.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

const Series _series = Series(
  id: 7,
  title: 'Abysses',
  groupingKey: 'abysses',
  versionCount: 1,
  year: 2024,
);

Episode _episode(int season, int number, {String? overview, int entry = 7}) =>
    Episode(
      id: entry * 1000 + season * 100 + number,
      seriesEntryId: entry,
      season: season,
      number: number,
      title: 'Abysses',
      contentKey: 'x:e:$entry:$season$number',
      locator: DirectStream('http://s/$entry/e$season$number.mkv'),
      overview: overview,
    );

/// Deux versions : la VF (entrée 7, deux saisons) et la VO (entrée 8, une
/// saison de trois épisodes).
const List<MediaVersion> _twoVersions = [
  MediaVersion(seriesEntryId: 8, label: 'EN', rawTitle: 'EN - Abysses'),
  MediaVersion(seriesEntryId: 7, label: 'FR', rawTitle: 'FR - Abysses'),
];

const String _overview =
    'Une équipe de plongeurs découvre une station sous-marine abandonnée.';

final class _Catalog extends Fake implements CatalogRepository {
  _Catalog({
    required this.details,
    this.overviews = true,
    this.versions = const [],
  });

  final TitleDetails details;
  final bool overviews;
  final List<MediaVersion> versions;

  @override
  Future<List<MediaVersion>> versionsOf(
    int sourceId,
    String groupingKey,
  ) async => versions;

  @override
  Future<List<Season>> seasonsOf(int sourceId, int seriesEntryId) async =>
      seriesEntryId == 8
      ? [
          Season(
            number: 1,
            episodes: [
              for (final number in [1, 2, 3]) _episode(1, number, entry: 8),
            ],
          ),
        ]
      : [
          Season(
            number: 1,
            episodes: [
              _episode(
                1,
                1,
                overview: overviews ? 'Léa rejoint l équipe de Marc.' : null,
              ),
              _episode(1, 2),
            ],
          ),
          Season(number: 2, episodes: [_episode(2, 1)]),
        ];

  @override
  Future<TitleDetails> seriesDetails(int sourceId, int seriesEntryId) async =>
      details;

  /// Résumés gardés après une recherche sur TMDB ou TVmaze.
  final Map<String, String> savedOverviews = {};

  @override
  Future<String?> tmdbIdOfEpisode(int sourceId, String contentKey) async =>
      null;

  @override
  Future<void> saveEpisodeOverviews(
    int seriesEntryId,
    Map<String, String> overviews,
  ) async => savedOverviews.addAll(overviews);
}

/// Résumés que TMDB ou TVmaze donnent pour la saison demandée.
final class _Summaries implements EpisodeSummaryRepository {
  const _Summaries(this.found);

  final Map<int, String> found;

  @override
  Future<Map<int, String>> seasonSummaries({
    required String title,
    int? year,
    String? tmdbId,
    required int season,
    required String language,
  }) async => season == 1 ? found : const {};
}

/// Positions enregistrées, toutes versions confondues, la plus récente
/// d'abord.
final class _Progress extends Fake implements WatchProgressRepository {
  _Progress(List<WatchProgress> items) : items = [...items];

  final List<WatchProgress> items;

  @override
  Future<List<WatchProgress>> progressOf(int sourceId, String key) async => [
    for (final item in items)
      if (item.workKey == key || item.seriesKey == key) item,
  ];

  @override
  Future<void> save(WatchProgress progress) async => items
    ..removeWhere((item) => item.contentKey == progress.contentKey)
    ..insert(0, progress);

  @override
  Future<void> remove(int sourceId, String contentKey) async =>
      items.removeWhere((item) => item.contentKey == contentKey);

  /// Épisodes vus jusqu'au bout, par saison et numéro.
  List<(int?, int?)> get finished => [
    for (final item in items)
      if (item.finished) (item.season, item.episode),
  ];
}

/// S1 É2 commencé en VO, à 21 minutes.
final WatchProgress _startedInEnglish = WatchProgress(
  sourceId: 1,
  contentKey: 'x:e:8:12',
  kind: ContentKind.series,
  title: 'Abysses',
  position: const Duration(minutes: 21),
  duration: const Duration(minutes: 45),
  updatedAt: DateTime.utc(2026, 11, 13),
  locator: const DirectStream('http://s/8/e12.mkv'),
  workKey: WorkKeys.episode('abysses', 1, 2),
  seriesKey: 'abysses',
  season: 1,
  episode: 2,
);

final class _Schedule implements ScheduleRepository {
  const _Schedule(this.schedule, {this.fails = false});

  final ShowSchedule? schedule;
  final bool fails;

  @override
  Future<ShowSchedule?> scheduleOf(String title, {int? year}) async {
    if (fails) throw const NetworkFailure('TVmaze injoignable');
    return schedule;
  }
}

final ShowSchedule _running = ShowSchedule(
  running: true,
  upcoming: [
    UpcomingEpisode(
      season: 2,
      number: 5,
      airDate: DateTime(2026, 11, 19),
      title: 'Les épaves',
    ),
    UpcomingEpisode(season: 2, number: 6, airDate: DateTime(2026, 11, 26)),
  ],
);

/// Diffusés depuis peu : S2 É1 est déjà dans la playlist, les trois suivants
/// non.
final ShowSchedule _behind = ShowSchedule(
  running: true,
  aired: [
    UpcomingEpisode(
      season: 2,
      number: 1,
      airDate: DateTime(2026, 11, 6),
      title: 'Plongée',
    ),
    UpcomingEpisode(
      season: 2,
      number: 2,
      airDate: DateTime(2026, 11, 13),
      title: 'Le retour',
    ),
    UpcomingEpisode(season: 2, number: 3, airDate: DateTime(2026, 11, 15)),
    UpcomingEpisode(season: 2, number: 4, airDate: DateTime(2026, 11, 16)),
  ],
  upcoming: _running.upcoming,
);

Future<_Progress> _open(
  WidgetTester tester, {
  TitleDetails details = const TitleDetails(
    overview: _overview,
    genre: 'Drame',
  ),
  ScheduleRepository? schedule,
  bool overviews = true,
  Map<int, String> found = const {},
  List<MediaVersion> versions = const [],
  List<WatchProgress> progress = const [],
  String language = 'fr',
  Size size = const Size(1280, 720),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final saved = _Progress(progress);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(AppSettings(languageCode: language)),
        catalogRepositoryProvider.overrideWithValue(
          _Catalog(details: details, overviews: overviews, versions: versions),
        ),
        watchProgressRepositoryProvider.overrideWithValue(saved),
        scheduleRepositoryProvider.overrideWithValue(
          schedule ?? _Schedule(_running),
        ),
        episodeSummaryRepositoryProvider.overrideWithValue(_Summaries(found)),
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
        home: const MediaDetailScreen(
          sourceId: 1,
          series: _series,
          seriesEntryId: 7,
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  return saved;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> _choose(WidgetTester tester, String option) async {
  await tester.tap(find.text(option));
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

/// Lignes d'épisodes affichées, par titre, vues jusqu'au bout ou non.
Map<String, bool> _watchedLines(WidgetTester tester) => {
  for (final line in tester.widgetList<EpisodeLine>(find.byType(EpisodeLine)))
    line.title: line.watched?.finished ?? false,
};

/// Vrai si l'élément qui a le focus le montre par son cadre.
bool _focusIsVisible() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context is! Element) return false;
  var visible = false;
  void visit(Element element) {
    if (element.widget case FocusFrame(focused: true)) visible = true;
    if (!visible) element.visitChildren(visit);
  }

  context.visitChildren(visit);
  return visible;
}

void main() {
  testWidgets('à l ouverture, le focus se voit', (tester) async {
    await _open(tester);
    expect(
      _focusIsVisible(),
      isTrue,
      reason: '${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('changer de saison laisse le focus sur la saison', (
    tester,
  ) async {
    await _open(tester);
    Future<void> press(LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
      await tester.pump();
    }

    await press(LogicalKeyboardKey.arrowLeft);
    await press(LogicalKeyboardKey.arrowDown);

    expect(find.text('Épisode 2'), findsNothing);
    expect(
      tester
          .widgetList<SeasonLine>(find.byType(SeasonLine))
          .where((line) => line.focused)
          .map((line) => line.text),
      ['Saison 2'],
    );
    await press(LogicalKeyboardKey.arrowUp);
    expect(find.text('Épisode 2'), findsOneWidget);
  });

  testWidgets('montre le résumé, le genre et le nombre de saisons', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text(_overview), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('Drame'), findsOneWidget);
    expect(find.text('2 saisons'), findsOneWidget);
    expect(find.text('En cours de diffusion'), findsOneWidget);
  });

  testWidgets('montre le résumé sous l épisode', (tester) async {
    await _open(tester);

    expect(find.text('Léa rejoint l équipe de Marc.'), findsOneWidget);
    final title = tester.getRect(find.text('Épisode 1'));
    final summary = tester.getRect(find.text('Léa rejoint l équipe de Marc.'));
    expect(summary.top, greaterThan(title.bottom));
  });

  testWidgets('complète un résumé que le fournisseur ne donne pas', (
    tester,
  ) async {
    await _open(
      tester,
      found: const {1: 'Autre résumé.', 2: 'Marc quitte le port.'},
    );

    // Celui du fournisseur reste.
    expect(find.text('Léa rejoint l équipe de Marc.'), findsOneWidget);
    expect(find.text('Autre résumé.'), findsNothing);
    expect(find.text('Marc quitte le port.'), findsOneWidget);
  });

  testWidgets('sans résumé nulle part, un texte neutre', (tester) async {
    await _open(tester, overviews: false);

    expect(find.text('Aucune description disponible'), findsNWidgets(2));
  });

  testWidgets('annonce les prochains épisodes avec leur date', (tester) async {
    await _open(tester);

    expect(find.text('Prochains épisodes'), findsOneWidget);
    expect(find.text('Jeudi 19 novembre'), findsOneWidget);
    expect(find.text('S2 É5, Les épaves'), findsOneWidget);
    expect(find.text('S2 É6, Titre non annoncé'), findsOneWidget);
    expect(find.textContaining('TVmaze'), findsOneWidget);
  });

  testWidgets('garde un épisode diffusé absent de la playlist, en rouge', (
    tester,
  ) async {
    await _open(tester, schedule: _Schedule(_behind));

    expect(find.text('Vendredi 13 novembre'), findsOneWidget);
    expect(find.text('S2 É2, Le retour'), findsOneWidget);
    expect(find.text('S2 É3, Titre non annoncé'), findsOneWidget);
    // Déjà dans la playlist : pas en retard.
    expect(find.text('S2 É1, Plongée'), findsNothing);
    final late = find.text("Retard sur l'IPTV");
    expect(late, findsNWidgets(3));
    expect(
      tester.widget<Text>(late.first).style?.color,
      const Color(0xFFFF6B6B),
    );
    // Les retards passent devant les prochains épisodes.
    expect(find.text('S2 É5, Les épaves'), findsNothing);
  });

  testWidgets('une série finie depuis peu montre encore ses retards', (
    tester,
  ) async {
    await _open(
      tester,
      schedule: _Schedule(ShowSchedule(running: false, aired: _behind.aired)),
    );

    expect(find.text('En cours de diffusion'), findsNothing);
    expect(find.text('S2 É2, Le retour'), findsOneWidget);
    expect(find.text("Retard sur l'IPTV"), findsNWidgets(3));
  });

  testWidgets('une seule version n a pas de bouton Version', (tester) async {
    await _open(tester, versions: [_twoVersions.last]);

    expect(find.text('Version'), findsNothing);
    expect(find.text('Français'), findsNothing);
  });

  testWidgets('change de version sans quitter la fiche', (tester) async {
    await _open(tester, versions: _twoVersions);

    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Épisode 3'), findsNothing);

    await tester.tap(find.text('Version'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Anglais'));
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.byType(MediaDetailScreen), findsOneWidget);
    expect(find.text('Anglais'), findsOneWidget);
    expect(find.text('Saison 2'), findsNothing);
    expect(find.text('Épisode 3'), findsOneWidget);
    // Le focus reste sur le bouton Version.
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'DetailVersion');
  });

  testWidgets('propose de reprendre un épisode commencé dans une autre '
      'version', (tester) async {
    await _open(tester, versions: _twoVersions, progress: [_startedInEnglish]);

    expect(find.text('Saison 1, épisode 2'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);
  });

  testWidgets('marque les épisodes vus et commencés, toutes versions '
      'confondues', (tester) async {
    final first = WatchProgress(
      sourceId: 1,
      contentKey: 'x:e:7:11',
      kind: ContentKind.series,
      title: 'Abysses',
      position: const Duration(minutes: 45),
      duration: const Duration(minutes: 45),
      updatedAt: DateTime.utc(2026, 11, 12),
      locator: const DirectStream('http://s/7/e11.mkv'),
      workKey: WorkKeys.episode('abysses', 1, 1),
      seriesKey: 'abysses',
      season: 1,
      episode: 1,
      finished: true,
    );
    await _open(
      tester,
      versions: _twoVersions,
      progress: [_startedInEnglish, first],
    );

    final marks = find.byType(WatchedMark);
    expect(marks, findsOneWidget);
    // La marque est sur la ligne de l'épisode 1.
    Widget rowOf(Finder finder) => tester.widget(
      find.ancestor(of: finder, matching: find.byType(Row)).first,
    );
    expect(rowOf(marks), same(rowOf(find.text('Épisode 1'))));
    final bar = tester.widget<ProgressTrack>(find.byType(ProgressTrack));
    expect(bar.fraction, closeTo(21 / 45, 0.001));
  });

  testWidgets('sans l épisode dans cette version, pas de reprise', (
    tester,
  ) async {
    final third = WatchProgress(
      sourceId: 1,
      contentKey: 'x:e:8:13',
      kind: ContentKind.series,
      title: 'Abysses',
      position: const Duration(minutes: 5),
      duration: const Duration(minutes: 45),
      updatedAt: DateTime.utc(2026, 11, 14),
      locator: const DirectStream('http://s/8/e13.mkv'),
      workKey: WorkKeys.episode('abysses', 1, 3),
      seriesKey: 'abysses',
      season: 1,
      episode: 3,
    );
    await _open(tester, versions: _twoVersions, progress: [third]);

    expect(find.text('Reprendre'), findsNothing);
  });

  group('menu d un épisode', () {
    testWidgets('la touche Menu l ouvre, et marque l épisode vu', (
      tester,
    ) async {
      final saved = await _open(tester);

      await _press(tester, LogicalKeyboardKey.contextMenu);
      // Jamais commencé : rien à reprendre, rien à oublier.
      expect(find.text('Lire'), findsOneWidget);
      expect(find.text('Reprendre'), findsNothing);
      expect(find.text('Marquer comme non vu'), findsNothing);
      // Le premier épisode : « jusqu'ici » serait le même choix.
      expect(find.text('Marquer vus jusqu\'ici'), findsNothing);
      expect(find.text('Marquer la saison comme vue'), findsOneWidget);
      await _choose(tester, 'Marquer comme vu');

      expect(saved.finished, [(1, 1)]);
      expect(_watchedLines(tester), {'Épisode 1': true, 'Épisode 2': false});
    });

    testWidgets('marque vus tous les épisodes jusqu ici, saisons '
        'précédentes comprises', (tester) async {
      final saved = await _open(tester);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowRight);

      await _press(tester, LogicalKeyboardKey.contextMenu);
      await _choose(tester, 'Marquer vus jusqu\'ici');

      expect(saved.finished, unorderedEquals([(1, 1), (1, 2), (2, 1)]));
    });

    testWidgets('un épisode commencé se reprend, ou s oublie dans toutes '
        'ses versions', (tester) async {
      final saved = await _open(
        tester,
        versions: _twoVersions,
        progress: [_startedInEnglish],
      );

      // Le focus est sur l'épisode commencé.
      await _press(tester, LogicalKeyboardKey.contextMenu);
      expect(find.text('Reprendre'), findsWidgets);
      expect(find.text('Lecture depuis le début'), findsOneWidget);
      await _choose(tester, 'Marquer comme non vu');

      expect(saved.items, isEmpty);
      expect(find.text('Reprendre'), findsNothing);
    });

    testWidgets('une saison vue peut redevenir non vue', (tester) async {
      final saved = await _open(tester);
      await _press(tester, LogicalKeyboardKey.contextMenu);
      await _choose(tester, 'Marquer la saison comme vue');
      expect(saved.finished, unorderedEquals([(1, 1), (1, 2)]));

      await _press(tester, LogicalKeyboardKey.contextMenu);
      await _choose(tester, 'Marquer la saison comme non vue');

      expect(saved.items, isEmpty);
    });

    testWidgets('une version sans l épisode le dit', (tester) async {
      await _open(tester, versions: _twoVersions);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      await _press(tester, LogicalKeyboardKey.arrowDown);
      await _press(tester, LogicalKeyboardKey.arrowRight);

      await _press(tester, LogicalKeyboardKey.contextMenu);
      await _choose(tester, 'Choisir la version');
      // La VO n'a qu'une saison.
      await _choose(tester, 'Anglais');

      expect(
        find.text('Cet épisode n\'existe pas dans cette version'),
        findsOneWidget,
      );
      // Le message est au-dessus de la fiche et de son propre bouton Retour.
      await tester.tap(find.text('Retour').last);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(
        find.text('Cet épisode n\'existe pas dans cette version'),
        findsNothing,
      );
      expect(find.byType(MediaDetailScreen), findsOneWidget);
    });
  });

  testWidgets('une série terminée n a ni panneau ni étiquette', (tester) async {
    await _open(
      tester,
      schedule: const _Schedule(ShowSchedule(running: false)),
    );

    expect(find.text('Prochains épisodes'), findsNothing);
    expect(find.text('En cours de diffusion'), findsNothing);
  });

  testWidgets('sans TVmaze ni résumé, la fiche reste utilisable', (
    tester,
  ) async {
    await _open(
      tester,
      details: TitleDetails.none,
      schedule: const _Schedule(null, fails: true),
      overviews: false,
    );

    expect(find.text('Prochains épisodes'), findsNothing);
    expect(find.text('Drame'), findsNothing);
    expect(find.text('Épisode 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final size in const [Size(1280, 720), Size(1920, 1080)]) {
      testWidgets('tient dans l écran (${locale.languageCode}, $size)', (
        tester,
      ) async {
        await _open(
          tester,
          language: locale.languageCode,
          size: size,
          // Le cas le plus haut : trois épisodes en retard, une reprise et
          // le bouton Version.
          schedule: _Schedule(_behind),
          versions: _twoVersions,
          progress: [_startedInEnglish],
          details: TitleDetails(
            overview: List.filled(12, _overview).join(' '),
            genre: 'Drame, Science-fiction, Mystère, Aventure',
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
