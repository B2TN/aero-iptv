import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/features/media_detail/open_movie.dart';
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
  title: 'Lagon',
  rawTitle: '$tag - Lagon',
  contentKey: 'cle$id',
  locator: DirectStream('http://s/$id.mkv'),
  languageTag: tag,
);

final class _Catalog extends Fake implements CatalogRepository {
  _Catalog(this.versions);

  final List<Movie> versions;

  @override
  Future<List<Movie>> moviesByTitleKeys(int sourceId, Set<String> keys) async =>
      versions;
}

final class _Engine extends Fake implements PlaybackEngine {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();
  final List<String> opened = [];

  @override
  PlaybackState get state => const PlaybackState();

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  Stream<String> get subtitleCues => const Stream.empty();

  @override
  Future<void> open(PlaybackRequest request) async =>
      opened.add(request.stream.url);

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
  List<Movie> movies, {
  AppSettings settings = const AppSettings(),
}) async {
  final engine = _Engine();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeSourceProvider.overrideWithValue(_source),
        settingsProvider.overrideWithValue(settings),
        catalogRepositoryProvider.overrideWithValue(_Catalog(movies)),
        playbackEngineFactoryProvider.overrideWithValue(() => engine),
        videoSurfaceBuilderProvider.overrideWithValue(
          (_) => const SizedBox.expand(),
        ),
        watchProgressRepositoryProvider.overrideWithValue(_NoProgress()),
        resolveStreamUrlProvider.overrideWithValue(
          ResolveStreamUrl(_NoCredentials()),
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
            onTap: () => openMovie(context, ref, movies.first),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return engine;
}

/// Ferme l'écran, ce qui annule les minuteries du lecteur.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  testWidgets('demande la version avant de lire le film', (tester) async {
    final engine = await _open(tester, [_movie(1, 'EN'), _movie(2, 'FR')]);

    expect(engine.opened, isEmpty);
    final first = tester.getTopLeft(find.text('Français')).dy;
    final second = tester.getTopLeft(find.text('Anglais')).dy;
    expect(first, lessThan(second));

    await tester.tap(find.text('Français'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(engine.opened, ['http://s/2.mkv']);
    await _leave(tester);
  });

  testWidgets('une seule version part directement en lecture', (tester) async {
    final engine = await _open(tester, [_movie(1, 'FR')]);

    expect(find.text('Français'), findsNothing);
    expect(engine.opened, ['http://s/1.mkv']);
    await _leave(tester);
  });

  testWidgets('sans regroupement, lit la version choisie sans demander', (
    tester,
  ) async {
    final engine = await _open(tester, [
      _movie(1, 'EN'),
      _movie(2, 'FR'),
    ], settings: const AppSettings(groupMovies: false));

    expect(find.text('Français'), findsNothing);
    expect(engine.opened, ['http://s/1.mkv']);
    await _leave(tester);
  });
}
