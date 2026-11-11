import 'dart:io';

import 'package:aero_iptv/app/aero_iptv_app.dart';
import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/bootstrap.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

import 'support/fake_panel.dart';

const int _mebibyte = 1024 * 1024;

/// Sans service de tendances, l'accueil montre l'ordre de la playlist.
final class _NoTrending implements TrendingRepository {
  const _NoTrending();

  @override
  bool get isAvailable => false;

  @override
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    required String language,
    String? region,
  }) async => const [];
}

/// Import réel, dans son isolate, d'un catalogue Xtream servi par l'appareil.
///
/// À lancer sur un appareil ou un émulateur à mémoire limitée :
/// flutter test integration_test/large_import_test.dart -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, int milliseconds) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: milliseconds)),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Lance l'application sur une playlist servie par [panel], puis attend la fin
  /// de son import. Retourne les messages d'avancement vus à l'accueil.
  Future<(ProviderContainer, Set<String>)> importFrom(
    WidgetTester tester,
    FakePanel panel, {
    required Duration limit,
  }) async {
    late Directory directory;
    late Widget app;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('iptv_import');
      app = await bootstrap(
        dataDirectory: directory,
        overrides: [
          trendingRepositoryProvider.overrideWithValue(const _NoTrending()),
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
            name: 'Essai',
            // Compte fictif, valable sur ce seul panneau de test.
            credentials: XtreamCredentials(
              serverUrl: panel.baseUrl,
              username: 'essai',
              password: 'essai',
            ),
          );
      source = (result as Ok<PlaylistSource>).value;
    });
    // L'ajout déclenche déjà l'import : cet appel est alors sans effet.
    container.read(importControllerProvider.notifier).start(source);

    final l10n = lookupAppLocalizations(const Locale('fr'));
    final seen = <String>{};
    final clock = Stopwatch()..start();
    while (clock.elapsed < limit) {
      await wait(tester, 500);
      final status = container.read(importControllerProvider);
      final message = importMessage(l10n, status);
      if (status.running && message != null) {
        seen.add(message.replaceAll(RegExp(r'\d+'), 'N'));
      }
      if (status.finished || status.failure != null) break;
    }
    await wait(tester, 2000);
    return (container, seen);
  }

  testWidgets('importe 300 000 titres sans dépasser la mémoire', (
    tester,
  ) async {
    late FakePanel panel;
    await tester.runAsync(() async {
      panel = await FakePanel.start(
        channels: 55000,
        movies: 200000,
        series: 46000,
      );
    });
    final before = ProcessInfo.currentRss;
    final clock = Stopwatch()..start();

    final (container, seen) = await importFrom(
      tester,
      panel,
      limit: const Duration(minutes: 40),
    );
    final status = container.read(importControllerProvider);
    // ignore: avoid_print
    print(
      'MESURE import : ${clock.elapsed.inSeconds} s, '
      '${status.processed} éléments, '
      'mémoire avant ${before ~/ _mebibyte} Mio, '
      'pic ${ProcessInfo.maxRss ~/ _mebibyte} Mio\n'
      'MESURE étapes vues : ${seen.join(' | ')}',
    );

    expect(status.failure, isNull);
    expect(status.finished, isTrue);
    expect(status.failedSections, isEmpty);
    expect(status.processed, 301000);
    expect(seen, hasLength(greaterThanOrEqualTo(4)));
    expect(find.text('Cette playlist est encore vide'), findsNothing);
    expect(find.text('Films populaires'), findsOneWidget);
    expect(find.text('Séries populaires'), findsOneWidget);
    await tester.runAsync(panel.close);
  }, timeout: const Timeout(Duration(minutes: 45)));

  testWidgets('garde le reste quand le panneau refuse une section', (
    tester,
  ) async {
    late FakePanel panel;
    await tester.runAsync(() async {
      panel = await FakePanel.start(
        channels: 3000,
        movies: 4000,
        series: 2000,
        cutsChannelsOnce: true,
        refusesSeries: true,
      );
    });

    final (container, _) = await importFrom(
      tester,
      panel,
      limit: const Duration(minutes: 5),
    );
    final status = container.read(importControllerProvider);
    // ignore: avoid_print
    print(
      'MESURE pannes : fini ${status.finished}, échec ${status.failure}, '
      'sections ${status.failedSections}, demandes ${panel.calls}',
    );

    // La liste coupée a été redemandée, et reçue en entier la seconde fois.
    expect(panel.calls['get_live_streams'], 2);
    expect(status.failure, isNull);
    expect(status.failedSections.keys, [ContentKind.series]);
    expect(status.processed, 7000);
    expect(find.text('Films populaires'), findsOneWidget);
    expect(find.text('Séries populaires'), findsNothing);
    expect(find.textContaining('Non reçu : séries'), findsOneWidget);
    await tester.runAsync(panel.close);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
