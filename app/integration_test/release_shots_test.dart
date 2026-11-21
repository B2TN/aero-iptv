// Captures des notes de version et du README, lancées par
// `tool/capture_release_shots.ps1`.
//
// L'application démarre dans un dossier temporaire, en anglais, avec la
// playlist donnée par les variables d'environnement du script : aucun
// identifiant n'est écrit dans le projet, et le dossier, son coffre compris,
// est supprimé à la fin. Aucune capture ne montre l'éditeur de playlist, seul
// écran où figurent l'adresse et le compte.
//
// Le même fichier sert à la 0.2.0 et à la 0.3 : il ne passe que par des
// fonctions communes aux deux versions. Le tutoriel, apparu après la 0.2.0,
// est reconnu à son nom.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:aero_iptv/app/aero_iptv_app.dart';
import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/bootstrap.dart';
import 'package:aero_iptv/features/home/screens/home_screen.dart';
import 'package:aero_iptv/features/live_tv/providers/live_tv_providers.dart';
import 'package:aero_iptv/features/media_detail/open_movie.dart';
import 'package:aero_iptv/features/media_detail/open_series.dart';
import 'package:aero_iptv/features/media_detail/screens/media_detail_screen.dart';
import 'package:aero_iptv/features/media_detail/screens/movie_detail_screen.dart';
import 'package:aero_iptv/features/player/screens/player_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:path/path.dart' as p;

import 'support/demo_server.dart';

/// Taille des captures : celle d'une TV en Full HD.
const Size _screen = Size(1920, 1080);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final shots = env['AERO_SHOTS'];
  final root = GlobalKey();

  /// Attend en dessinant l'écran tout du long, comme l'application : les
  /// fondus et les délais d'affichage se déroulent comme à l'écran.
  Future<void> wait(WidgetTester tester, int milliseconds) async {
    final clock = Stopwatch()..start();
    do {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    } while (clock.elapsedMilliseconds < milliseconds);
    await tester.pump();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    debugPrint('CAPTURE $name');
    if (shots == null) return;
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File(p.join(shots, '$name.png'));
      await file.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await wait(tester, 220);
  }

  /// Attend qu'un écran du type [type] apparaisse, au plus [seconds].
  Future<bool> waitFor(WidgetTester tester, Type type, int seconds) async {
    for (var i = 0; i < seconds * 5; i++) {
      if (find.byType(type).evaluate().isNotEmpty) return true;
      await wait(tester, 200);
    }
    return false;
  }

  /// Attend [screen], en choisissant la première version si le choix s'ouvre
  /// d'abord : un titre en plusieurs versions le demande. OK n'est pressé que
  /// sur ce choix, jamais à l'aveugle.
  Future<bool> openPast(WidgetTester tester, Type screen) async {
    final picker = find.text('Choose a version');
    for (var i = 0; i < 100; i++) {
      if (find.byType(screen).evaluate().isNotEmpty) return true;
      if (picker.evaluate().isNotEmpty) {
        await press(tester, LogicalKeyboardKey.enter);
        await wait(tester, 600);
      } else {
        await wait(tester, 200);
      }
    }
    debugPrint('Écran $screen pas ouvert');
    return false;
  }

  /// Attend la fin des chargements visibles, au plus [seconds].
  Future<void> settle(WidgetTester tester, int seconds) async {
    final loading = find.text('Loading');
    for (var i = 0; i < seconds * 2 && loading.evaluate().isNotEmpty; i++) {
      await wait(tester, 500);
    }
  }

  /// Ferme tout ce qui est ouvert au-dessus des onglets : fiches, lecteur ou
  /// choix restés ouverts.
  Future<void> backToTabs(WidgetTester tester, BuildContext tabs) async {
    Navigator.of(tabs).popUntil((route) => route.isFirst);
    await wait(tester, 800);
  }

  /// Le titre le plus proche de [wanted] parmi les résultats de [kind] : le
  /// titre exact, sinon celui qui commence pareil, sinon le premier.
  SearchHit? pick(List<SearchHit> hits, ContentKind kind, String wanted) {
    final matching = hits.where((hit) => hit.kind == kind).toList();
    final lower = wanted.toLowerCase();
    return matching
            .where((hit) => hit.title.toLowerCase() == lower)
            .firstOrNull ??
        matching
            .where((hit) => hit.title.toLowerCase().startsWith(lower))
            .firstOrNull ??
        matching.firstOrNull;
  }

  testWidgets('captures de la version', (tester) async {
    final PlaylistCredentials credentials;
    final m3u = env['AERO_M3U_URL'];
    // Essai du parcours sans compte : la playlist de démonstration des tests.
    DemoServer? demo;
    if (env['AERO_DEMO'] != null) {
      await tester.runAsync(() async => demo = await DemoServer.start());
      credentials = M3uCredentials(
        playlistUrl: '${demo!.baseUrl}/playlist.m3u',
      );
    } else if (m3u != null && m3u.isNotEmpty) {
      credentials = M3uCredentials(playlistUrl: m3u);
    } else {
      credentials = XtreamCredentials(
        serverUrl: env['AERO_XTREAM_SERVER'] ?? '',
        username: env['AERO_XTREAM_USER'] ?? '',
        password: env['AERO_XTREAM_PASSWORD'] ?? '',
      );
    }
    final seriesTitle = env['AERO_SERIES'] ?? 'Dexter';
    final movieTitles = (env['AERO_MOVIE'] ?? 'Dune: Part Two|Dune').split('|');
    final channelPattern = RegExp(
      env['AERO_CHANNEL'] ?? r'^A ?& ?E\b',
      caseSensitive: false,
    );

    tester.view
      ..physicalSize = _screen
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late Directory directory;
    late Widget app;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('aero_shots');
      app = await bootstrap(dataDirectory: directory);
    });
    addTearDown(() async {
      // Le dossier contient le coffre de la playlist : il ne reste pas.
      await tester.runAsync(() => directory.delete(recursive: true));
      await tester.runAsync(() async => demo?.close());
    });
    await tester.pumpWidget(RepaintBoundary(key: root, child: app));
    await wait(tester, 1200);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AeroIptvApp)),
    );
    Future<void> settings(AppSettings Function(AppSettings) change) =>
        tester.runAsync(
          () => container
              .read(settingsRepositoryProvider)
              .save(change(container.read(settingsProvider))),
        );

    // Pas de tutoriel : l'application en anglais, directement.
    final tutorial = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == 'TutorialScreen',
    );
    for (var i = 0; i < 20 && tutorial.evaluate().isEmpty; i++) {
      await wait(tester, 200);
    }
    if (tutorial.evaluate().isNotEmpty) {
      Navigator.of(tester.element(tutorial)).pop();
    }
    await settings((current) => current.copyWith(languageCode: 'en'));
    await wait(tester, 600);

    late PlaylistSource source;
    await tester.runAsync(() async {
      final result = await container
          .read(playlistRepositoryProvider)
          .add(name: 'Playlist', credentials: credentials);
      source = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError('Playlist refusée : $failure'),
      };
    });
    await settings((current) => current.copyWith(activeSourceId: source.id));
    container.read(importControllerProvider.notifier).start(source);
    // Un gros catalogue prend quelques minutes au premier import.
    final clock = Stopwatch()..start();
    while (!container.read(importControllerProvider).finished) {
      if (clock.elapsed > const Duration(minutes: 40)) {
        fail('Import trop long.');
      }
      await wait(tester, 1000);
    }
    expect(container.read(importControllerProvider).failure, isNull);
    debugPrint('Import terminé en ${clock.elapsed.inSeconds} s');
    // Tendances, affiches et grand visuel.
    await wait(tester, 20000);
    await shot(tester, '01_home');

    final home = tester.element(find.byType(HomeScreen));
    final ref = home as WidgetRef;
    final search = container.read(searchRepositoryProvider);
    final catalog = container.read(catalogRepositoryProvider);

    // Fiche de la série.
    late List<SearchHit> seriesHits;
    await tester.runAsync(() async {
      seriesHits = (await search.search(
        source.id,
        seriesTitle,
        const PageRequest(),
        language: 'en',
      )).items;
    });
    final seriesHit = pick(seriesHits, ContentKind.series, seriesTitle);
    debugPrint('Série : ${seriesHit?.title ?? 'introuvable'}');
    if (seriesHit != null) {
      Series? series;
      await tester.runAsync(() async {
        series = await catalog.seriesById(seriesHit.id);
      });
      if (series != null) {
        openSeries(home, ref, series!).ignore();
        if (await openPast(tester, MediaDetailScreen)) {
          await wait(tester, 10000);
          await shot(tester, '02_series');
        }
        await backToTabs(tester, home);
      }
    }

    // Fiche du film, puis sa lecture.
    SearchHit? movieHit;
    for (final title in movieTitles) {
      late List<SearchHit> hits;
      await tester.runAsync(() async {
        hits = (await search.search(
          source.id,
          title,
          const PageRequest(),
          language: 'en',
        )).items;
      });
      movieHit = pick(hits, ContentKind.movie, title);
      if (movieHit != null) break;
    }
    debugPrint('Film : ${movieHit?.title ?? 'introuvable'}');
    if (movieHit != null) {
      Movie? movie;
      await tester.runAsync(() async {
        movie = await catalog.movieById(movieHit!.id);
      });
      if (movie != null) {
        openMovie(home, ref, movie!).ignore();
        if (await openPast(tester, MovieDetailScreen)) {
          await wait(tester, 10000);
          await shot(tester, '03_movie');
          // Lecture : le bouton Lire a le focus.
          await press(tester, LogicalKeyboardKey.enter);
        }
        if (await waitFor(tester, PlayerScreen, 10)) {
          await wait(tester, 9000);
          // Les commandes s'affichent au moindre appui.
          await press(tester, LogicalKeyboardKey.arrowDown);
          await wait(tester, 800);
          await shot(tester, '04_player');
          for (
            var i = 0;
            i < 3 && find.byType(PlayerScreen).evaluate().isNotEmpty;
            i++
          ) {
            await press(tester, LogicalKeyboardKey.escape);
            await wait(tester, 800);
          }
        }
        await backToTabs(tester, home);
      }
    }

    // Chaînes : le pays de la chaîne voulue, son groupe, puis la chaîne.
    final live = container.read(liveTvRepositoryProvider);
    final grouped = container.read(settingsProvider).groupChannels;
    String? countryCode;
    var groupIndex = 0;
    var channelIndex = 0;
    await tester.runAsync(() async {
      final countries = await live.countries(source.id);
      final ordered = [
        ...countries.where((country) => country.code == 'US'),
        ...countries.where((country) => country.code != 'US'),
      ];
      for (final country in ordered.take(6)) {
        final groups = await live.groups(
          source.id,
          country.code,
          grouped: grouped,
        );
        for (final (index, group) in groups.indexed.skip(1)) {
          final channels = await live.channels(
            source.id,
            country.code,
            group,
            const PageRequest(limit: 400),
            grouped: grouped,
          );
          final found = channels.items.indexWhere(
            (channel) => channelPattern.hasMatch(channel.name),
          );
          if (found >= 0) {
            countryCode = country.code;
            groupIndex = index;
            channelIndex = found;
            return;
          }
        }
      }
      countryCode = ordered.firstOrNull?.code;
    });
    container.read(currentTabProvider.notifier).show(AppTab.live);
    await wait(tester, 1500);
    if (countryCode != null) {
      container.read(selectedCountryProvider.notifier).select(countryCode);
      await wait(tester, 2500);
      for (var i = 0; i < groupIndex; i++) {
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
      await wait(tester, 1500);
      await press(tester, LogicalKeyboardKey.arrowRight);
      for (var i = 0; i < channelIndex; i++) {
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
      await wait(tester, 4000);
    }
    await shot(tester, '05_channels');

    container.read(currentTabProvider.notifier).show(AppTab.settings);
    await wait(tester, 2000);
    await shot(tester, '06_settings');

    // Mode Performance : les mêmes écrans, sans flou ni animation.
    await settings((current) => current.copyWith(performanceMode: true));
    container.read(currentTabProvider.notifier).show(AppTab.home);
    await wait(tester, 3000);
    await settle(tester, 120);
    await wait(tester, 12000);
    await shot(tester, '07_performance');
  });
}
