import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/home/screens/home_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

const PlaylistSource _source = PlaylistSource(
  id: 1,
  name: 'Essai',
  kind: SourceKind.xtream,
);

Series _series(int id) => Series(
  id: id,
  title: 'Série $id',
  groupingKey: 'serie $id',
  versionCount: 1,
);

/// Version du catalogue : la changer recharge l'accueil, comme une
/// synchronisation.
class _Catalog extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final _catalogProvider = NotifierProvider<_Catalog, int>(_Catalog.new);

final class _NoFavorites implements FavoritesRepository {
  @override
  Stream<List<Favorite>> watch(int sourceId) => Stream.value(const []);

  @override
  Future<void> add(Favorite favorite) async {}

  @override
  Future<void> remove(int sourceId, ContentKind kind, String key) async {}
}

void main() {
  testWidgets('un rechargement garde la carte active et le défilement', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 720)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reload = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        sourcesProvider.overrideWith((ref) => Stream.value(const [_source])),
        favoritesRepositoryProvider.overrideWithValue(_NoFavorites()),
        homeFeedProvider.overrideWith((ref) async {
          // Le second chargement attend, comme une base occupée.
          if (ref.watch(_catalogProvider) > 0) await reload.future;
          return HomeFeed(
            hero: const [],
            continueWatching: const [],
            series: [for (var id = 1; id <= 12; id++) _series(id)],
            movies: const [],
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    // La rangée reçoit le focus, puis on avance de quatre cartes.
    FocusManager.instance.primaryFocus?.focusInDirection(
      TraversalDirection.down,
    );
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
    }
    final card = FocusManager.instance.primaryFocus;
    final before = tester.getTopLeft(find.text('Série 5').last);

    container.read(_catalogProvider.notifier).refresh();
    await tester.pump();
    await tester.pump();

    // Pendant le rechargement : ni « Chargement », ni perte de place.
    expect(find.text('Chargement'), findsNothing);
    expect(FocusManager.instance.primaryFocus, same(card));

    reload.complete();
    await tester.pump();
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, same(card));
    expect(tester.getTopLeft(find.text('Série 5').last), before);
  });

  test('relire la même playlist ne la change pas', () {
    final later = PlaylistSource(
      id: 1,
      name: 'Essai',
      kind: SourceKind.xtream,
      lastSyncedAt: DateTime.utc(2026, 11, 18),
    );
    expect(
      const PlaylistSource(id: 1, name: 'Essai', kind: SourceKind.xtream),
      _source,
    );
    expect(later, isNot(_source));
  });
}
