import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/design_system/components/progress_track.dart';
import 'package:aero_iptv/features/home/widgets/continue_card.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

const Series _abysses = Series(
  id: 7,
  title: 'Abysses',
  groupingKey: 'abysses',
  versionCount: 2,
);

Episode _episode(int number, String title) => Episode(
  id: 300 + number,
  seriesEntryId: 8,
  season: 3,
  number: number,
  title: title,
  contentKey: 'x:e:3$number',
  locator: DirectStream('http://s/e3$number.mkv'),
);

final class _Catalog extends Fake implements CatalogRepository {
  @override
  Future<(Series, Episode)?> episodeByContentKey(
    int sourceId,
    String contentKey,
  ) async => switch (contentKey) {
    'x:e:32' => (_abysses, _episode(2, 'Le phare')),
    // Sans titre propre : le fournisseur répète celui de la série.
    'x:e:33' => (_abysses, _episode(3, 'Abysses')),
    _ => null,
  };

  @override
  Future<List<MediaVersion>> versionsOf(
    int sourceId,
    String groupingKey,
  ) async => const [
    MediaVersion(seriesEntryId: 7, label: 'FR', rawTitle: 'FR - Abysses'),
    MediaVersion(seriesEntryId: 8, label: 'EN', rawTitle: 'EN - Abysses'),
  ];

  @override
  Future<Movie?> movieByContentKey(int sourceId, String contentKey) async =>
      null;
}

WatchProgress _item(
  int number, {
  Duration position = Duration.zero,
  Duration duration = Duration.zero,
}) => WatchProgress(
  sourceId: 1,
  contentKey: 'x:e:3$number',
  kind: ContentKind.series,
  title: 'Abysses',
  position: position,
  duration: duration,
  updatedAt: DateTime.utc(2026, 11, 18),
  locator: DirectStream('http://s/e3$number.mkv'),
  seriesKey: 'abysses',
  season: 3,
  episode: number,
);

Future<void> _pump(WidgetTester tester, WatchProgress item) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        catalogRepositoryProvider.overrideWithValue(_Catalog()),
      ],
      child: WidgetsApp(
        color: const Color(0xFF000000),
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, _) => Center(
          child: SizedBox(
            width: 274,
            height: 192,
            child: ContinueCard(item: item, focused: false),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('montre l épisode, sa version, le temps vu et la barre', (
    tester,
  ) async {
    await _pump(
      tester,
      _item(
        2,
        position: const Duration(minutes: 20, seconds: 15),
        duration: const Duration(minutes: 42),
      ),
    );

    expect(find.text('Abysses'), findsOneWidget);
    expect(find.text('S3 É2'), findsOneWidget);
    expect(find.text('Le phare'), findsOneWidget);
    expect(find.text('Anglais'), findsOneWidget);
    expect(find.text('20:15 / 42:00'), findsOneWidget);
    final bar = tester.widget<ProgressTrack>(find.byType(ProgressTrack));
    expect(bar.fraction, closeTo(20.25 / 42, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('un épisode suivant pas encore commencé est « À suivre »', (
    tester,
  ) async {
    await _pump(tester, _item(3));

    expect(find.text('S3 É3'), findsOneWidget);
    // Le titre de la série n'est pas répété comme titre d'épisode.
    expect(find.text('Abysses'), findsOneWidget);
    expect(find.text('À suivre'), findsOneWidget);
    expect(find.byType(ProgressTrack), findsNothing);
  });

  testWidgets('une reprise inconnue du catalogue garde sa carte', (
    tester,
  ) async {
    await _pump(
      tester,
      _item(
        9,
        position: const Duration(hours: 1, minutes: 5, seconds: 12),
        duration: const Duration(hours: 1, minutes: 52),
      ),
    );

    expect(find.text('Abysses'), findsOneWidget);
    expect(find.text('S3 É9'), findsOneWidget);
    expect(find.text('1:05:12 / 1:52:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
