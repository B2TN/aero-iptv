import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/media_detail/screens/media_detail_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
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

Episode _episode(int season, int number, {String? overview}) => Episode(
  id: season * 100 + number,
  seriesEntryId: 7,
  season: season,
  number: number,
  title: 'Abysses',
  contentKey: 'x:e:$season$number',
  locator: DirectStream('http://s/e$season$number.mkv'),
  overview: overview,
);

const String _overview =
    'Une équipe de plongeurs découvre une station sous-marine abandonnée.';

final class _Catalog extends Fake implements CatalogRepository {
  _Catalog({required this.details, this.overviews = true});

  final TitleDetails details;
  final bool overviews;

  @override
  Future<List<Season>> seasonsOf(int sourceId, int seriesEntryId) async => [
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
}

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

Future<void> _open(
  WidgetTester tester, {
  TitleDetails details = const TitleDetails(
    overview: _overview,
    genre: 'Drame',
  ),
  ScheduleRepository? schedule,
  bool overviews = true,
  String language = 'fr',
  Size size = const Size(1280, 720),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(AppSettings(languageCode: language)),
        catalogRepositoryProvider.overrideWithValue(
          _Catalog(details: details, overviews: overviews),
        ),
        scheduleRepositoryProvider.overrideWithValue(
          schedule ?? _Schedule(_running),
        ),
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
}

void main() {
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

  testWidgets('annonce les prochains épisodes avec leur date', (tester) async {
    await _open(tester);

    expect(find.text('Prochains épisodes'), findsOneWidget);
    expect(find.text('Jeudi 19 novembre'), findsOneWidget);
    expect(find.text('S2 É5, Les épaves'), findsOneWidget);
    expect(find.text('S2 É6, Titre non annoncé'), findsOneWidget);
    expect(find.textContaining('TVmaze'), findsOneWidget);
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
