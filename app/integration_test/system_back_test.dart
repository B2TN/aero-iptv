import 'dart:io';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/aero_iptv_app.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/bootstrap.dart';
import 'package:aero_iptv/features/live_tv/providers/live_tv_providers.dart';
import 'package:aero_iptv/features/media_detail/screens/media_detail_screen.dart';
import 'package:aero_iptv/features/player/screens/player_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

import 'support/demo_server.dart';
import 'support/fake_trending.dart';

/// Retour envoyé par Android lui-même, et non simulé dans Flutter : le test
/// annonce « ATTENTE RETOUR n » dans le journal, et le script qui le lance
/// répond par `adb shell input keyevent KEYCODE_BACK`.
///
/// Sur un vrai Android, la touche arrive en deux temps : l'appui, que Flutter
/// traite, puis le relâchement. Un relâchement laissé sans suite repartait
/// vers Android, qui en faisait un second retour : ce test le surveille.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, int milliseconds) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: milliseconds)),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await wait(tester, 250);
  }

  /// Attend le Retour d'Android, qui doit fermer l'écran [screen].
  Future<void> awaitSystemBack(
    WidgetTester tester,
    int step,
    Finder screen,
  ) async {
    expect(screen, findsWidgets, reason: 'écran attendu avant le retour $step');
    debugPrint('ATTENTE RETOUR $step');
    final clock = Stopwatch()..start();
    while (screen.evaluate().isNotEmpty &&
        clock.elapsed < const Duration(seconds: 60)) {
      await wait(tester, 200);
    }
    expect(screen, findsNothing, reason: 'le retour $step n est pas arrivé');
    // Le temps qu'un éventuel second retour arrive.
    await wait(tester, 2000);
  }

  testWidgets('un Retour d Android ne ferme qu un écran', (tester) async {
    late DemoServer server;
    late Directory directory;
    late Widget app;
    await tester.runAsync(() async {
      server = await DemoServer.start();
      directory = await Directory.systemTemp.createTemp('iptv_back');
      app = await bootstrap(
        dataDirectory: directory,
        overrides: [
          trendingRepositoryProvider.overrideWithValue(
            FakeTrending(server.baseUrl),
          ),
        ],
      );
    });
    await tester.pumpWidget(app);
    await wait(tester, 900);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AeroIptvApp)),
    );

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
    await wait(tester, 1500);

    // 1. Une fiche de série ouverte depuis l'accueil : au retour, la même
    // carte a le focus, et non l'onglet Accueil de la barre.
    await press(tester, LogicalKeyboardKey.arrowDown);
    final card = FocusManager.instance.primaryFocus;
    await press(tester, LogicalKeyboardKey.enter);
    if (find.text('Choisissez une version').evaluate().isNotEmpty) {
      await press(tester, LogicalKeyboardKey.enter);
    }
    await wait(tester, 800);
    await awaitSystemBack(tester, 1, find.byType(MediaDetailScreen));
    expect(container.read(currentTabProvider), AppTab.home);
    expect(
      FocusManager.instance.primaryFocus,
      same(card),
      reason: 'focus après le retour : ${FocusManager.instance.primaryFocus}',
    );

    // 2. Une chaîne en direct : au retour, la liste des chaînes du pays, et
    // non la grille des pays.
    container.read(currentTabProvider.notifier).show(AppTab.live);
    await wait(tester, 900);
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 900);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.enter);
    await wait(tester, 800);
    if (find.text('Choisissez un flux').evaluate().isNotEmpty) {
      await press(tester, LogicalKeyboardKey.enter);
    }
    await wait(tester, 1500);
    await awaitSystemBack(tester, 2, find.byType(PlayerScreen));
    expect(
      container.read(selectedCountryProvider),
      isNotNull,
      reason: 'le pays ouvert a été refermé',
    );

    debugPrint('FIN DU TEST');
    await tester.pumpWidget(const SizedBox.shrink());
    await wait(tester, 400);
    await tester.runAsync(() async {
      container.dispose();
      await server.close();
    });
  }, timeout: const Timeout(Duration(minutes: 4)));
}
