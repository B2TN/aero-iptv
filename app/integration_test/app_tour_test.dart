import 'dart:io';
import 'dart:ui' as ui;

import 'package:aero_iptv/app/aero_iptv_app.dart';
import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/bootstrap.dart';
import 'package:aero_iptv/features/home/screens/home_screen.dart';
import 'package:aero_iptv/features/media_detail/screens/movie_detail_screen.dart';
import 'package:aero_iptv/features/player/screens/player_screen.dart';
import 'package:aero_iptv/focus/focus_memory.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:path/path.dart' as p;

import 'support/demo_server.dart';
import 'support/visible_focus.dart';

/// Tendances simulées : elles imposent une image large, comme le ferait TMDb.
final class FakeTrending implements TrendingRepository {
  const FakeTrending(this._baseUrl);

  final String _baseUrl;

  @override
  bool get isAvailable => true;

  @override
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    required String language,
    String? region,
  }) async {
    TrendingItem item(String title, String overview, {bool backdrop = true}) =>
        TrendingItem(
          kind: kind,
          title: title,
          originalTitle: title,
          overview: overview,
          backdropUrl: backdrop
              ? '$_baseUrl/backdrop/${title.hashCode.abs()}.jpg'
              : null,
        );
    return kind == ContentKind.series
        ? [
            item(
              'Abysses',
              'Une équipe de plongeurs découvre une cité engloutie.',
            ),
            item('Port Royal', 'Un port, trois familles et un secret.'),
          ]
        : [
            item(
              'Le Dernier Récif',
              'Un biologiste tente de sauver un récif condamné.',
            ),
            // Sans image large, le héros retombe sur l'affiche verticale.
            item(
              'Marée Haute',
              'Une ville côtière face à la tempête.',
              backdrop: false,
            ),
          ];
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final shots = Platform.environment['AERO_SHOTS'];
  final root = GlobalKey();

  Future<void> wait(WidgetTester tester, int milliseconds) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: milliseconds)),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // Une ligne par étape : sur un appareil sans captures, le journal dit
    // jusqu'où la visite est allée.
    debugPrint('ÉTAPE $name');
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

  /// Quitte le lecteur : un Retour masque les commandes, le suivant ferme.
  /// Sur l'émulateur, sans sortie vidéo, le fichier se termine aussitôt et le
  /// lecteur se ferme seul : un Retour de trop quitterait l'application.
  Future<void> leavePlayer(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      if (find.byType(PlayerScreen).evaluate().isEmpty) return;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await wait(tester, 500);
    }
  }

  /// Défilement vertical de l'accueil.
  double homeScroll(WidgetTester tester) {
    for (final element in find.byType(Scrollable).evaluate()) {
      final state = (element as StatefulElement).state as ScrollableState;
      if (state.position.axis == Axis.vertical) return state.position.pixels;
    }
    return -1;
  }

  /// Vérifie la promesse centrale : un élément a toujours le focus.
  void expectFocus(String where) {
    final primary = FocusManager.instance.primaryFocus;
    expect(primary, isNotNull, reason: where);
    expect(primary, isNot(isA<FocusScopeNode>()), reason: where);
  }

  /// Attend que [label] ait le focus. Ce banc ne produit des images qu'à la
  /// demande : une vérification immédiate dépendrait de l'ordre des événements.
  Future<void> waitForFocus(WidgetTester tester, String label) async {
    final clock = Stopwatch()..start();
    while (clock.elapsed < const Duration(seconds: 5) &&
        FocusManager.instance.primaryFocus?.debugLabel != label) {
      await wait(tester, 100);
    }
    expect(FocusManager.instance.primaryFocus?.debugLabel, label);
  }

  /// Écran en cours, pour nommer la capture d'un focus invisible.
  var where = 'accueil';

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    int times = 1,
  }) async {
    for (var i = 0; i < times; i++) {
      await tester.sendKeyEvent(key);
      await wait(tester, 170);
      expectFocus('après ${key.keyLabel}');
      // Le focus se voit toujours : jamais de curseur « disparu ». Le cadre
      // peut n'apparaître qu'à l'image suivante, ce qui ne se voit pas.
      for (var frame = 0; frame < 6 && !focusIsVisible(); frame++) {
        await wait(tester, 50);
      }
      if (!focusIsVisible()) await shot(tester, 'focus_invisible_$where');
      expect(
        focusIsVisible(),
        isTrue,
        reason:
            'focus invisible sur $where après ${key.keyLabel} : '
            '${describeFocus()}',
      );
    }
  }

  testWidgets('visite complète au D-pad', (tester) async {
    late DemoServer server;
    late Directory directory;
    await tester.runAsync(() async {
      server = await DemoServer.start();
      directory = await Directory.systemTemp.createTemp('iptv_tour');
    });

    late Widget app;
    await tester.runAsync(() async {
      app = await bootstrap(
        dataDirectory: directory,
        overrides: [
          trendingRepositoryProvider.overrideWithValue(
            FakeTrending(server.baseUrl),
          ),
        ],
      );
    });
    await tester.pumpWidget(RepaintBoundary(key: root, child: app));
    await wait(tester, 900);

    final element = tester.element(find.byType(AeroIptvApp));
    final container = ProviderScope.containerOf(element);

    // Sans playlist, le focus attend sur l'action à faire.
    expectFocus('accueil vide');
    expect(find.text('Ajouter une playlist'), findsOneWidget);
    await shot(tester, '01_accueil_vide');

    // Ajout d'une playlist, puis import réel dans un isolate.
    late PlaylistSource source;
    await tester.runAsync(() async {
      final result = await container
          .read(playlistRepositoryProvider)
          .add(
            name: 'Démonstration',
            credentials: M3uCredentials(
              playlistUrl: '${server.baseUrl}/playlist.m3u',
            ),
          );
      source = (result as Ok<PlaylistSource>).value;
    });
    container.read(importControllerProvider.notifier).start(source);
    for (var i = 0; i < 80; i++) {
      await wait(tester, 200);
      if (container.read(importControllerProvider).finished) break;
    }
    expect(container.read(importControllerProvider).failure, isNull);
    await wait(tester, 1500);

    await waitForFocus(tester, 'HeroAction');
    await shot(tester, '02_accueil');

    // Accueil : Informations, titre suivant, puis rangées.
    await press(tester, LogicalKeyboardKey.arrowRight, times: 2);
    await wait(tester, 500);
    await shot(tester, '03_carrousel_suivant');
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowRight, times: 2);
    await wait(tester, 500);
    await shot(tester, '04_rangee_series');

    // Une série à deux versions ouvre le sélecteur, puis le détail.
    await press(tester, LogicalKeyboardKey.arrowLeft, times: 2);
    final cardBefore = FocusManager.instance.primaryFocus;
    final scrollBefore = homeScroll(tester);
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 500);
    expectFocus('sélecteur de version');
    await shot(tester, '05_versions');
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 700);
    expectFocus('détail de la série');
    await shot(tester, '06_detail_serie');
    where = 'fiche_serie';
    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
    ]) {
      await press(tester, key);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await wait(tester, 400);
    expectFocus('retour du détail');
    // Au retour, la même carte de la même rangée, au même défilement.
    expect(FocusManager.instance.primaryFocus, same(cardBefore));
    expect(homeScroll(tester), scrollBefore);

    // Live TV : barre, drapeaux, puis chaînes.
    await press(tester, LogicalKeyboardKey.arrowUp, times: 3);
    final tab = container.read(currentTabProvider);
    expect(tab, AppTab.home);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 900);
    expect(container.read(currentTabProvider), AppTab.live);
    expectFocus('drapeaux');
    await shot(tester, '07_drapeaux');
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 900);
    expectFocus('groupes');
    await shot(tester, '08_groupes_chaines');
    where = 'chaines';
    for (final key in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
    ]) {
      await press(tester, key);
    }
    // Retour referme le pays, puis on y revient par son drapeau.
    await press(tester, LogicalKeyboardKey.escape);
    await wait(tester, 600);
    expect(find.text('Choisissez un pays'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 900);
    expectFocus('groupes, de retour');

    // Une chaîne à trois qualités ouvre le menu de flux, puis le lecteur.
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 800);
    expectFocus('menu de flux');
    await shot(tester, '09_choix_du_flux');
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 2500);
    expectFocus('lecteur');
    await shot(tester, '10_lecteur');
    final playing = find.byType(PlayerScreen).evaluate().isNotEmpty;
    where = 'lecteur';
    for (final key in [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
    ]) {
      await press(tester, key);
    }
    if (playing) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await wait(tester, 400);
      expect(find.text('Pause'), findsNothing);
    }
    await leavePlayer(tester);
    await wait(tester, 400);
    expectFocus('retour du lecteur');

    // Recherche : clavier virtuel sur TV, vrai champ sur PC.
    container.read(currentTabProvider.notifier).show(AppTab.search);
    await wait(tester, 900);
    expectFocus('recherche');
    await shot(tester, '11_recherche_tendances');
    where = 'recherche';
    for (final key in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
    ]) {
      await press(tester, key);
    }
    // Le clavier reprend sa première touche, comme au début de l'étape : il
    // se souvient sinon de la dernière, laissée au bord par l'audit.
    container.read(focusMemoryProvider).clear('search.');
    container.read(currentTabProvider.notifier).show(AppTab.home);
    await wait(tester, 600);
    container.read(currentTabProvider.notifier).show(AppTab.search);
    await wait(tester, 900);
    if (Platform.isWindows) {
      // Sur PC, un vrai champ reçoit le clavier physique.
      await tester.enterText(find.byType(EditableText), 'ab');
    } else {
      // Sur TV, le clavier virtuel : « a », puis « b ».
      await press(tester, LogicalKeyboardKey.enter);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.enter);
    }
    await wait(tester, 900);
    expect(find.text('Abysses'), findsWidgets);
    await shot(tester, '12_recherche_resultats');

    // Paramètres et gestionnaire de playlists.
    container.read(currentTabProvider.notifier).show(AppTab.settings);
    await wait(tester, 600);
    expectFocus('paramètres');
    await shot(tester, '13_parametres');
    where = 'parametres';
    await press(tester, LogicalKeyboardKey.arrowDown, times: 12);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowUp, times: 12);
    // Haut depuis la liste mène à l'onglet affiché, pas à son voisin.
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'settings');
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 500);
    expectFocus('playlists');
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 500);
    await shot(tester, '14_editeur_playlist');
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 400);
    expectFocus('saisie');
    await shot(tester, '15_saisie_texte');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await wait(tester, 300);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await wait(tester, 300);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await wait(tester, 400);

    // L'interface bascule de sens en arabe.
    await tester.runAsync(() async {
      await container
          .read(settingsRepositoryProvider)
          .save(container.read(settingsProvider).copyWith(languageCode: 'ar'));
    });
    await wait(tester, 400);
    container.read(currentTabProvider.notifier).show(AppTab.home);
    await waitForFocus(tester, 'HeroAction');
    await wait(tester, 800);
    expectFocus('accueil en arabe');
    await shot(tester, '16_accueil_arabe');

    // Rangée « Continuer à regarder », avec ses barres d'avancement.
    await tester.runAsync(() async {
      final progress = container.read(watchProgressRepositoryProvider);
      final page = await container
          .read(catalogRepositoryProvider)
          .movies(source.id, const PageRequest(limit: 4));
      for (final (index, movie) in page.items.indexed) {
        await progress.save(
          WatchProgress(
            sourceId: source.id,
            contentKey: movie.contentKey,
            kind: ContentKind.movie,
            title: movie.title,
            position: Duration(minutes: 70 - index * 15),
            duration: const Duration(minutes: 110),
            updatedAt: DateTime.now(),
            locator: movie.locator,
            posterUrl: movie.posterUrl,
          ),
        );
      }
      await container
          .read(settingsRepositoryProvider)
          .save(container.read(settingsProvider).copyWith(languageCode: 'fr'));
    });
    await wait(tester, 400);
    container.invalidate(homeFeedProvider);
    await wait(tester, 1500);
    expectFocus('rangée continuer');
    await shot(tester, '17_continuer');

    // Lecture d'un film : barre de temps, horloge et commandes sur une ligne.
    await waitForFocus(tester, 'HeroAction');
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 600);
    if (find.text('Choisissez une version').evaluate().isNotEmpty) {
      await press(tester, LogicalKeyboardKey.enter);
    }
    await wait(tester, 1200);
    expectFocus('lecteur de film');
    await shot(tester, '18_lecteur_film');
    await leavePlayer(tester);
    await wait(tester, 400);
    expectFocus('retour du film');

    // Un film de la dernière rangée : fiche, lecture, puis retour. L'accueil
    // doit rendre la même carte, au même défilement.
    where = 'retour_lecture';
    await waitForFocus(tester, 'HeroAction');
    await press(tester, LogicalKeyboardKey.arrowDown, times: 3);
    await press(tester, LogicalKeyboardKey.arrowRight, times: 2);
    await wait(tester, 400);
    final movieCard = FocusManager.instance.primaryFocus;
    final movieScroll = homeScroll(tester);
    expect(movieScroll, greaterThan(0));
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 900);
    expectFocus('fiche du film');
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 2000);
    expectFocus('lecture depuis la fiche');
    await leavePlayer(tester);
    await wait(tester, 600);
    expect(find.byType(MovieDetailScreen), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await wait(tester, 1500);
    expectFocus('accueil après la lecture');
    await shot(tester, '19_retour_lecture');
    expect(FocusManager.instance.primaryFocus, same(movieCard));
    expect(homeScroll(tester), movieScroll);

    await tester.pumpWidget(const SizedBox.shrink());
    await wait(tester, 400);
    await tester.runAsync(() async {
      container.dispose();
      await server.close();
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
