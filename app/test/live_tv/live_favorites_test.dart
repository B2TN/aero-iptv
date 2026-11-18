import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/live_tv/screens/live_tv_screen.dart';
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

const Channel _tf1 = Channel(
  id: 1,
  name: 'TF1',
  groupingKey: 'tf1',
  countryCode: 'FR',
);

final class _LiveTv extends Fake implements LiveTvRepository {
  final List<List<({String? countryCode, String groupingKey})>> asked = [];

  @override
  Future<List<Country>> countries(int sourceId) async => const [
    Country(code: 'FR', channelCount: 1),
  ];

  @override
  Future<List<Channel>> channelsByKeys(
    int sourceId,
    List<({String? countryCode, String groupingKey})> keys,
  ) async {
    asked.add(keys);
    return [
      for (final key in keys)
        if (key.countryCode == 'FR' && key.groupingKey == 'tf1') _tf1,
    ];
  }
}

final class _Epg extends Fake implements EpgRepository {
  @override
  Future<Map<String, EpgProgramme>> nowPlaying(
    int sourceId,
    Iterable<String> epgKeys,
    DateTime at,
  ) async => const {};
}

final class _Favorites implements FavoritesRepository {
  _Favorites(this.items);

  final List<Favorite> items;
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

Favorite _channelFavorite() => Favorite(
  sourceId: 1,
  kind: ContentKind.live,
  key: 'FR|tf1',
  title: 'TF1',
  addedAt: DateTime.utc(2026, 11, 18),
);

Future<void> _pump(WidgetTester tester, _Favorites favorites) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        activeSourceProvider.overrideWithValue(_source),
        liveTvRepositoryProvider.overrideWithValue(_LiveTv()),
        epgRepositoryProvider.overrideWithValue(_Epg()),
        favoritesRepositoryProvider.overrideWithValue(favorites),
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
        home: const LiveTvScreen(),
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('les favoris passent avant les pays', (tester) async {
    await _pump(tester, _Favorites([_channelFavorite()]));

    final favorites = tester.getTopLeft(find.text('Favoris'));
    final france = tester.getTopLeft(find.text('France'));
    expect(favorites.dy, france.dy);
    expect(favorites.dx, lessThan(france.dx));
  });

  testWidgets('sans chaîne favorite, pas de tuile', (tester) async {
    await _pump(tester, _Favorites([]));

    expect(find.text('Favoris'), findsNothing);
    expect(find.text('France'), findsOneWidget);
  });

  testWidgets('la tuile ouvre la liste des chaînes favorites', (tester) async {
    await _pump(tester, _Favorites([_channelFavorite()]));

    await tester.tap(find.text('Favoris'));
    await _settle(tester);

    expect(find.text('TF1'), findsOneWidget);
  });

  testWidgets('la touche Menu retire une chaîne des favoris', (tester) async {
    final favorites = _Favorites([_channelFavorite()]);
    await _pump(tester, favorites);
    await tester.tap(find.text('Favoris'));
    await _settle(tester);

    // OK sur le groupe « Favoris » passe à ses chaînes.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await _settle(tester);
    expect(find.text('Retirer des favoris'), findsOneWidget);

    await tester.tap(find.text('Retirer des favoris'));
    await _settle(tester);
    expect(favorites.items, isEmpty);
  });
}
