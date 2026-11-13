import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/design_system/tokens/aero_tokens.dart';
import 'package:aero_iptv/features/player/player_target.dart';
import 'package:aero_iptv/features/player/screens/player_screen.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

const PlayerTarget _target = PlayerTarget(
  item: PlaybackItem(
    sourceId: 1,
    contentKey: 'live:lagon',
    title: 'Lagon',
    kind: ContentKind.live,
    locator: DirectStream('http://127.0.0.1/flux.ts'),
  ),
);

final class _FakeEngine implements PlaybackEngine {
  int opens = 0;

  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  @override
  PlaybackState state = const PlaybackState();

  @override
  Stream<PlaybackState> get states => _states.stream;

  void emit(PlaybackState next) {
    state = next;
    _states.add(next);
  }

  @override
  Future<void> open(PlaybackRequest request) async {
    opens++;
    emit(const PlaybackState(status: PlaybackStatus.opening));
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Stream<String> get subtitleCues => const Stream.empty();

  @override
  Future<void> setVolume(double percent) async {}

  @override
  Future<void> selectAudio(MediaTrack track) async {}

  @override
  Future<void> selectSubtitle(MediaTrack? track) async {}

  @override
  Future<List<MediaChapter>> chapters() async => const [];

  @override
  Future<void> dispose() => _states.close();
}

final class _NoProgress implements WatchProgressRepository {
  @override
  Future<void> save(WatchProgress progress) async {}

  @override
  Future<List<WatchProgress>> continueWatching(
    int sourceId, {
    int limit = 20,
  }) async => const [];

  @override
  Future<void> remove(int sourceId, String contentKey) async {}
}

final class _Probe implements StreamProbe {
  const _Probe(this.result);

  final StreamProbeResult? result;

  @override
  Future<StreamProbeResult?> probe(ResolvedStream stream) async => result;
}

final class _NoCredentials implements CredentialStore {
  @override
  Future<PlaylistCredentials?> read(int sourceId) async => null;

  @override
  Future<void> write(int sourceId, PlaylistCredentials credentials) async {}

  @override
  Future<void> delete(int sourceId) async {}
}

Future<_FakeEngine> _openPlayer(
  WidgetTester tester,
  StreamProbeResult? answer,
) async {
  final engine = _FakeEngine();
  final probe = _Probe(answer);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(const AppSettings()),
        playbackEngineFactoryProvider.overrideWithValue(() => engine),
        videoSurfaceBuilderProvider.overrideWithValue(
          (_) => const SizedBox.expand(),
        ),
        watchProgressRepositoryProvider.overrideWithValue(_NoProgress()),
        streamProbeProvider.overrideWithValue(probe),
        resolveStreamUrlProvider.overrideWithValue(
          ResolveStreamUrl(_NoCredentials()),
        ),
      ],
      child: WidgetsApp(
        navigatorKey: navigator,
        color: const Color(0xFF000000),
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        shortcuts: dpadShortcuts,
        home: const SizedBox.shrink(),
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
      ),
    ),
  );
  unawaited(
    navigator.currentState!.push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => const PlayerScreen(target: _target),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return engine;
}

void main() {
  const failed = PlaybackState(status: PlaybackStatus.failed);
  const refused = StreamProbeResult(status: 458, isVideo: false);

  testWidgets('une connexion occupée est réessayée sans message d erreur', (
    tester,
  ) async {
    final engine = await _openPlayer(tester, refused);

    engine.emit(failed);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('nouvel essai'), findsOneWidget);
    expect(find.text('Retour'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    expect(engine.opens, 2);

    // La connexion précédente est libérée : la lecture démarre.
    engine.emit(const PlaybackState(status: PlaybackStatus.playing));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('nouvel essai'), findsNothing);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Retour'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('après trois essais, explique que les connexions sont prises', (
    tester,
  ) async {
    final engine = await _openPlayer(tester, refused);

    for (var attempt = 0; attempt < 3; attempt++) {
      engine.emit(failed);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    }
    expect(engine.opens, 4);

    engine.emit(failed);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Toutes vos connexions sont utilisées'), findsOneWidget);
    expect(find.textContaining('hors ligne'), findsNothing);
    expect(find.textContaining('HTTP 458'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'PlayerFailure');

    await tester.pump(const Duration(seconds: 10));
    expect(engine.opens, 4);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('un autre refus n est pas réessayé', (tester) async {
    final engine = await _openPlayer(
      tester,
      const StreamProbeResult(status: 403),
    );

    engine.emit(failed);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));

    expect(engine.opens, 1);
    expect(find.textContaining('hors ligne'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('quitter pendant un essai annule le suivant', (tester) async {
    final engine = await _openPlayer(tester, refused);

    engine.emit(failed);
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));

    expect(engine.opens, 1);
  });

  testWidgets("le message d'échec se quitte à la télécommande", (tester) async {
    final engine = await _openPlayer(
      tester,
      const StreamProbeResult(status: 401),
    );

    engine.emit(const PlaybackState(status: PlaybackStatus.failed));
    await tester.pump();
    await tester.pump();
    // La surcouche, disparue, ne doit pas reprendre le focus à son expiration.
    await tester.pump(const Duration(seconds: 6));

    // Sur une TV, le focus doit se voir : le bouton passe à son visuel vert.
    final button = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('Retour'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final image = (button.decoration as BoxDecoration).image!.image;
    expect((image as AssetImage).assetName, AeroAssets.pillBlueFocus);
    expect(find.textContaining('HTTP 401'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.select, platform: 'android');
    await tester.pump();
    await tester.pump();

    expect(find.byType(PlayerScreen), findsNothing);
  });
}
