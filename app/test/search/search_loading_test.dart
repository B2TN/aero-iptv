import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/home/screens/home_screen.dart';
import 'package:aero_iptv/features/search/screens/search_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

const PlaylistSource _source = PlaylistSource(
  id: 1,
  name: 'Essai',
  kind: SourceKind.xtream,
);

/// Recherche qui ne répond que lorsque le test le décide.
final class _SlowSearch extends Fake implements SearchRepository {
  Completer<List<SearchHit>> answer = Completer();

  @override
  Future<List<String>> suggest(
    int sourceId,
    String prefix, {
    int limit = 8,
  }) async => const [];

  @override
  Future<Page<SearchHit>> search(
    int sourceId,
    String query,
    PageRequest page, {
    required String language,
    bool groupMovies = true,
  }) async => Page(items: await answer.future, request: page);
}

Future<_SlowSearch> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final search = _SlowSearch();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        activeSourceProvider.overrideWithValue(_source),
        physicalKeyboardProvider.overrideWithValue(true),
        searchRepositoryProvider.overrideWithValue(search),
        homeFeedProvider.overrideWith((ref) async => null),
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
        home: const SearchScreen(),
      ),
    ),
  );
  await tester.pump();
  return search;
}

void main() {
  testWidgets('pendant la recherche, un chargement et pas « Aucun résultat »', (
    tester,
  ) async {
    final search = await _pump(tester);

    await tester.enterText(find.byType(EditableText), 'lagon');
    await tester.pump();
    expect(find.text('Recherche en cours…'), findsOneWidget);
    expect(find.textContaining('Aucun résultat'), findsNothing);

    // Le serveur tarde : toujours en cours, toujours pas de « vide ».
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Recherche en cours…'), findsOneWidget);
    expect(find.textContaining('Aucun résultat'), findsNothing);

    search.answer.complete(const []);
    await tester.pump();
    await tester.pump();
    expect(find.text('Recherche en cours…'), findsNothing);
    expect(find.textContaining('Aucun résultat'), findsOneWidget);
  });

  testWidgets('les résultats remplacent le chargement', (tester) async {
    final search = await _pump(tester);

    await tester.enterText(find.byType(EditableText), 'lagon');
    await tester.pump(const Duration(milliseconds: 300));
    search.answer.complete(const [
      SearchHit(kind: ContentKind.movie, id: 1, title: 'Lagon'),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('Recherche en cours…'), findsNothing);
    expect(find.text('Lagon'), findsWidgets);
  });
}
