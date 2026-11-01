import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:aero_iptv/app/platform/api_key_store.dart';
import 'package:aero_iptv/features/player/player_target.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

final class _Engine implements PlaybackEngine {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();
  final List<double> volumes = [];
  final List<PlaybackRequest> opened = [];
  final List<Duration> seeks = [];
  final List<MediaTrack?> selectedSubtitles = [];
  final List<SubtitleFile> loadedSubtitles = [];
  final StreamController<String> cues = StreamController<String>.broadcast();

  @override
  PlaybackState state = const PlaybackState();

  @override
  Stream<PlaybackState> get states => _states.stream;

  void emit(PlaybackState next) {
    state = next;
    _states.add(next);
  }

  @override
  Future<void> open(PlaybackRequest request) async => opened.add(request);

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Stream<String> get subtitleCues => cues.stream;

  @override
  Future<void> setVolume(double percent) async => volumes.add(percent);

  @override
  Future<void> selectAudio(MediaTrack track) async {}

  @override
  Future<void> selectSubtitle(MediaTrack? track) async =>
      selectedSubtitles.add(track);

  @override
  Future<void> loadSubtitle(SubtitleFile file) async =>
      loadedSubtitles.add(file);

  @override
  Future<void> dispose() => cues.close();
}

/// Marque chaque réplique de la langue demandée.
final class _Translator implements SubtitleTranslator {
  @override
  Future<List<String>> translateTexts(
    List<String> texts, {
    required String language,
  }) async => [for (final text in texts) '$language:$text'];

  @override
  Future<SubtitleFile> translate(
    SubtitleFile file, {
    required String language,
  }) async => file;
}

/// La clé n'arrive du coffre qu'au moment où le test le décide.
final class _LateKeyStore implements ApiKeyStore {
  final Completer<String?> key = Completer();

  @override
  Future<String?> read(String name) => key.future;

  @override
  Future<void> write(String name, String? value) async {}
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

final class _NoSubtitles implements SubtitleRepository {
  @override
  bool get isAvailable => false;

  @override
  Future<void> remember(SubtitleQuery query, SubtitleFile file) async {}

  @override
  Future<SubtitleFile?> find(SubtitleQuery query) async => null;
}

final class _OnlineSubtitles implements SubtitleRepository {
  @override
  bool get isAvailable => true;

  @override
  Future<void> remember(SubtitleQuery query, SubtitleFile file) async {}

  @override
  Future<SubtitleFile?> find(SubtitleQuery query) async => SubtitleFile(
    content: 'texte',
    language: query.language,
    title: query.title,
  );
}

final class _NoCredentials implements CredentialStore {
  @override
  Future<PlaylistCredentials?> read(int sourceId) async => null;

  @override
  Future<void> write(int sourceId, PlaylistCredentials credentials) async {}

  @override
  Future<void> delete(int sourceId) async {}
}

PlayerTarget _target(
  ContentKind kind, {
  PlayerVersionLoader? versions,
  String title = 'Lagon',
}) => PlayerTarget(
  versions: versions,
  item: PlaybackItem(
    sourceId: 1,
    contentKey: 'cle',
    title: title,
    kind: kind,
    locator: const DirectStream('http://127.0.0.1/flux'),
  ),
);

PlayerTarget _episode({PlayerTarget? next}) => PlayerTarget(
  next: (_) async => next,
  item: const PlaybackItem(
    sourceId: 1,
    contentKey: 'e1',
    title: 'Lagon S1 E1',
    kind: ContentKind.series,
    locator: DirectStream('http://127.0.0.1/flux'),
    season: 1,
    episode: 1,
  ),
);

PlaybackState _playingAt(Duration position) => PlaybackState(
  status: PlaybackStatus.playing,
  position: position,
  duration: _playing.duration,
  audioTracks: _playing.audioTracks,
  subtitleTracks: _playing.subtitleTracks,
);

const PlaybackState _playing = PlaybackState(
  status: PlaybackStatus.playing,
  position: Duration(minutes: 10),
  duration: Duration(minutes: 40),
  audioTracks: [
    MediaTrack(
      id: '1',
      kind: MediaTrackKind.audio,
      language: 'fre',
      channelCount: 2,
    ),
    MediaTrack(
      id: '2',
      kind: MediaTrackKind.audio,
      language: 'eng',
      channelCount: 1,
    ),
    MediaTrack(
      id: '3',
      kind: MediaTrackKind.audio,
      language: 'jpn',
      channelCount: 6,
    ),
  ],
  subtitleTracks: [
    MediaTrack(id: '1', kind: MediaTrackKind.subtitle, language: 'ger'),
  ],
);

const PlaybackState _withEnglishSubtitles = PlaybackState(
  status: PlaybackStatus.playing,
  position: Duration(minutes: 10),
  duration: Duration(minutes: 40),
  subtitleTracks: [
    MediaTrack(
      id: '1',
      kind: MediaTrackKind.subtitle,
      language: 'ger',
      codec: 'subrip',
    ),
    MediaTrack(
      id: '2',
      kind: MediaTrackKind.subtitle,
      language: 'eng',
      codec: 'subrip',
    ),
  ],
);

Future<_Engine> _pump(
  WidgetTester tester,
  PlayerTarget target, {
  String language = 'fr',
  Size window = const Size(1920, 1080),
  Widget home = const SizedBox.shrink(),
  ApiKeyStore keys = const MemorylessApiKeyStore(),
  PlaybackState state = _playing,
  SubtitleTranslator? translator,
  SubtitleRepository Function(String? key)? subtitles,
}) async {
  tester.view
    ..physicalSize = window
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final engine = _Engine();
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWithValue(AppSettings(languageCode: language)),
        apiKeyStoreProvider.overrideWithValue(keys),
        if (translator != null)
          subtitleTranslatorProvider.overrideWithValue(translator),
        playbackEngineFactoryProvider.overrideWithValue(() => engine),
        videoSurfaceBuilderProvider.overrideWithValue(
          (_) => const SizedBox.expand(),
        ),
        watchProgressRepositoryProvider.overrideWithValue(_NoProgress()),
        subtitleRepositoryProvider.overrideWith(
          (ref) =>
              subtitles?.call(ref.watch(openSubtitlesKeyProvider)) ??
              _NoSubtitles(),
        ),
        resolveStreamUrlProvider.overrideWithValue(
          ResolveStreamUrl(_NoCredentials()),
        ),
      ],
      child: WidgetsApp(
        navigatorKey: navigator,
        color: const Color(0xFF000000),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        shortcuts: dpadShortcuts,
        home: home,
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
      ),
    ),
  );
  unawaited(navigator.currentState!.push(playerRoute(target)));
  await tester.pump();
  await tester.pump();
  engine.emit(state);
  await tester.pump();
  await tester.pump();
  return engine;
}

/// Ferme l'écran, ce qui annule ses minuteries.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  testWidgets('le direct n affiche que les commandes demandées', (
    tester,
  ) async {
    await _pump(
      tester,
      _target(ContentKind.live, versions: (_, _) async => const []),
    );

    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Lecteur externe'), findsOneWidget);
    expect(find.text('Lagon'), findsNothing);
    expect(find.text('Audio'), findsNothing);
    expect(find.text('Sous-titres'), findsNothing);
    expect(find.textContaining('Fin à'), findsNothing);
    await _leave(tester);
  });

  testWidgets('la VOD affiche titre, heure de fin et pistes', (tester) async {
    await _pump(
      tester,
      _target(ContentKind.movie, versions: (_, _) async => const []),
    );

    expect(find.text('Lagon'), findsOneWidget);
    expect(find.textContaining('Fin à'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Sous-titres'), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('l heure de fin est dans l horloge, en haut à droite', (
    tester,
  ) async {
    await _pump(tester, _target(ContentKind.movie));

    final end = tester.getRect(find.textContaining('Fin à'));
    expect(end.top, lessThan(150));
    expect(end.left, greaterThan(tester.view.physicalSize.width / 2));
    await _leave(tester);
  });

  group('barre de temps', () {
    Future<void> focusSeekBar(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'PlayerSeekBar');
    }

    testWidgets('chaque flèche saute de 30 secondes', (tester) async {
      final engine = await _pump(tester, _target(ContentKind.movie));
      await focusSeekBar(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 1));

      expect(engine.seeks, [const Duration(minutes: 10, seconds: 30)]);

      engine.emit(_playingAt(const Duration(minutes: 10, seconds: 30)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(seconds: 1));

      expect(engine.seeks.last, const Duration(minutes: 10));
      await _leave(tester);
    });

    testWidgets('des appuis rapides s additionnent', (tester) async {
      final engine = await _pump(tester, _target(ContentKind.movie));
      await focusSeekBar(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 1));

      // Un seul saut pour le moteur : un stick ne suivrait pas trois recherches.
      expect(engine.seeks, [const Duration(minutes: 11, seconds: 30)]);
      expect(find.text('11:30'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('s arrête au début et avant la fin', (tester) async {
      final engine = await _pump(tester, _target(ContentKind.movie));
      await focusSeekBar(tester);
      engine.emit(_playingAt(const Duration(seconds: 10)));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(seconds: 1));
      expect(engine.seeks.last, Duration.zero);

      engine.emit(_playingAt(const Duration(minutes: 39, seconds: 50)));
      await tester.pump(const Duration(seconds: 5));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 1));
      expect(engine.seeks.last, const Duration(minutes: 39, seconds: 59));
      await _leave(tester);
    });

    testWidgets('un clic place la lecture', (tester) async {
      final engine = await _pump(tester, _target(ContentKind.movie));
      final start = tester.getRect(find.text('10:00'));
      final end = tester.getRect(find.text('40:00'));

      await tester.tapAt(Offset((start.right + end.left) / 2, start.center.dy));
      await tester.pump(const Duration(seconds: 1));

      expect(engine.seeks.single.inSeconds, closeTo(20 * 60, 10));
      await _leave(tester);
    });

    testWidgets('glisser ne saute qu au relâchement', (tester) async {
      final engine = await _pump(tester, _target(ContentKind.movie));
      final start = tester.getRect(find.text('10:00'));
      final end = tester.getRect(find.text('40:00'));
      final y = start.center.dy;

      final gesture = await tester.startGesture(Offset(start.right + 60, y));
      await gesture.moveTo(Offset((start.right + end.left) / 2, y));
      await tester.pump();
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(seconds: 1));
      expect(engine.seeks, isEmpty);

      await gesture.up();
      await tester.pump(const Duration(seconds: 1));

      expect(engine.seeks, hasLength(1));
      await _leave(tester);
    });

    testWidgets('surcouche fermée, une flèche saute et l ouvre', (
      tester,
    ) async {
      final engine = await _pump(tester, _target(ContentKind.movie));
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Audio'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump();

      expect(find.text('Audio'), findsOneWidget);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'PlayerSeekBar');
      await tester.pump(const Duration(seconds: 1));
      expect(engine.seeks, [const Duration(minutes: 10, seconds: 30)]);
      await _leave(tester);
    });

    testWidgets('le direct n a pas de barre de temps', (tester) async {
      await _pump(tester, _target(ContentKind.live));
      expect(find.text('40:00'), findsNothing);
      await _leave(tester);
    });
  });

  group('épisode', () {
    const start = Duration(minutes: 1);
    const skipIntro = "Passer l'intro";
    const nextEpisode = 'Épisode suivant';

    testWidgets('passer l intro avance d un saut, une seule fois', (
      tester,
    ) async {
      final engine = await _pump(tester, _episode(), state: _playingAt(start));

      await tester.tap(find.text(skipIntro));
      await tester.pump(const Duration(seconds: 1));

      expect(engine.seeks, [const Duration(minutes: 2, seconds: 25)]);
      expect(find.text(skipIntro), findsNothing);
      await _leave(tester);
    });

    testWidgets('l intro n est plus proposée après les premières minutes', (
      tester,
    ) async {
      await _pump(
        tester,
        _episode(),
        state: _playingAt(const Duration(minutes: 6)),
      );

      expect(find.text(skipIntro), findsNothing);
      await _leave(tester);
    });

    testWidgets('un film n a ni intro ni épisode suivant', (tester) async {
      await _pump(tester, _target(ContentKind.movie), state: _playingAt(start));

      expect(find.text(skipIntro), findsNothing);
      expect(find.text(nextEpisode), findsNothing);
      await _leave(tester);
    });

    testWidgets('le dernier épisode n a pas de bouton suivant', (tester) async {
      await _pump(tester, _episode(), state: _playingAt(start));

      expect(find.text(nextEpisode), findsNothing);
      await _leave(tester);
    });

    testWidgets('épisode suivant ouvre l épisode', (tester) async {
      final engine = await _pump(
        tester,
        _episode(next: _target(ContentKind.series, title: 'Lagon S1 E2')),
        state: _playingAt(start),
      );
      await tester.pump();

      await tester.tap(find.text(nextEpisode));
      await tester.pump();
      await tester.pump();

      expect(find.text('Lagon S1 E2'), findsOneWidget);
      expect(engine.opened, hasLength(2));
      await _leave(tester);
    });

    testWidgets('commandes fermées, valider passe l intro', (tester) async {
      final engine = await _pump(tester, _episode(), state: _playingAt(start));
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Pause'), findsNothing);
      expect(find.text(skipIntro), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(seconds: 1));

      expect(engine.seeks, hasLength(1));
      expect(find.text('Pause'), findsNothing);
      await _leave(tester);
    });

    testWidgets('commandes fermées, le bouton se clique', (tester) async {
      final engine = await _pump(tester, _episode(), state: _playingAt(start));
      await tester.pump(const Duration(seconds: 6));

      await tester.tap(find.text(skipIntro));
      await tester.pump(const Duration(seconds: 1));

      expect(engine.seeks, hasLength(1));
      await _leave(tester);
    });

    testWidgets('le générique de fin propose l épisode suivant', (
      tester,
    ) async {
      final engine = await _pump(
        tester,
        _episode(next: _target(ContentKind.series, title: 'Lagon S1 E2')),
        state: _playingAt(const Duration(minutes: 39)),
      );
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Pause'), findsNothing);
      expect(find.text(nextEpisode), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();

      expect(engine.opened, hasLength(2));
      await _leave(tester);
    });

    testWidgets('au milieu de l épisode, rien ne recouvre la vidéo', (
      tester,
    ) async {
      await _pump(
        tester,
        _episode(next: _target(ContentKind.series)),
        state: _playingAt(const Duration(minutes: 20)),
      );
      await tester.pump(const Duration(seconds: 6));

      expect(find.text(skipIntro), findsNothing);
      expect(find.text(nextEpisode), findsNothing);
      await _leave(tester);
    });

    testWidgets('une recherche de suite en échec ne gêne pas la lecture', (
      tester,
    ) async {
      await _pump(
        tester,
        PlayerTarget(
          next: (_) async => throw const NetworkFailure('hors ligne'),
          item: _episode().item,
        ),
        state: _playingAt(start),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(nextEpisode), findsNothing);
      await _leave(tester);
    });
  });

  testWidgets('le menu audio donne la langue et les canaux', (tester) async {
    await _pump(tester, _target(ContentKind.movie));

    await tester.tap(find.text('Audio'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Français (stéréo)'), findsOneWidget);
    expect(find.text('Anglais (mono)'), findsOneWidget);
    expect(find.text('Japonais (5.1)'), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('le menu des sous-titres suit l ordre demandé', (tester) async {
    await _pump(tester, _target(ContentKind.movie));

    await tester.tap(find.text('Sous-titres'));
    await tester.pump();
    await tester.pump();

    final disable = tester.getTopLeft(find.text('Désactiver')).dy;
    final track = tester.getTopLeft(find.text('Allemand')).dy;
    expect(disable, lessThan(track));
    expect(find.text('Télécharger sous-titre'), findsNothing);
    await _leave(tester);
  });

  testWidgets(
    'une clé DeepL lue après l ouverture du lecteur sert quand même',
    (tester) async {
      final store = _LateKeyStore();
      final engine = await _pump(
        tester,
        _target(ContentKind.movie),
        keys: store,
        state: _withEnglishSubtitles,
      );

      store.key.complete('cle:fx');
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Sous-titres'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Télécharger sous-titre'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Français'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('ne contient aucun'), findsNothing);
      expect(engine.selectedSubtitles.single?.language, 'eng');
      await _leave(tester);
    },
  );

  testWidgets(
    'une clé OpenSubtitles lue après l ouverture du lecteur sert quand même',
    (tester) async {
      final store = _LateKeyStore();
      final engine = await _pump(
        tester,
        _target(ContentKind.movie),
        keys: store,
        subtitles: (key) => key == null ? _NoSubtitles() : _OnlineSubtitles(),
      );

      store.key.complete('cle');
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Sous-titres'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Télécharger sous-titre'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Français'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(engine.loadedSubtitles.single.language, 'fr');
      await _leave(tester);
    },
  );

  group('télécharger sous-titre', () {
    Future<_Engine> openLanguages(
      WidgetTester tester, {
      PlaybackState state = _withEnglishSubtitles,
    }) async {
      final engine = await _pump(
        tester,
        _target(ContentKind.movie),
        state: state,
        translator: _Translator(),
      );
      await tester.tap(find.text('Sous-titres'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Télécharger sous-titre'));
      await tester.pump();
      await tester.pump();
      return engine;
    }

    testWidgets('demande d abord la langue, celle de l application en tête', (
      tester,
    ) async {
      final engine = await openLanguages(tester);

      expect(find.text('Traduire les sous-titres en'), findsOneWidget);
      expect(engine.selectedSubtitles, isEmpty);
      final first = tester.getTopLeft(find.text('Français')).dy;
      final next = tester.getTopLeft(find.text('Allemand')).dy;
      expect(first, lessThan(next));
      await _leave(tester);
    });

    testWidgets('traduit la piste anglaise vers la langue choisie', (
      tester,
    ) async {
      final engine = await openLanguages(tester);

      // Le français est en tête : l'espagnol est plus bas dans la liste.
      await tester.tap(find.text('Bulgare'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(engine.selectedSubtitles.single?.language, 'eng');

      engine.cues.add('Hello');
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('bg:Hello'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('annuler le choix ne touche à rien', (tester) async {
      final engine = await openLanguages(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump();

      expect(engine.selectedSubtitles, isEmpty);
      await _leave(tester);
    });

    testWidgets('dit quand les sous-titres sont des images', (tester) async {
      await openLanguages(
        tester,
        state: const PlaybackState(
          status: PlaybackStatus.playing,
          duration: Duration(minutes: 40),
          subtitleTracks: [
            MediaTrack(
              id: '1',
              kind: MediaTrackKind.subtitle,
              language: 'eng',
              codec: 'hdmv_pgs_subtitle',
            ),
          ],
        ),
      );

      await tester.tap(find.text('Français'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('sont des images'), findsOneWidget);
      await _leave(tester);
    });

    testWidgets('dit quand la source n a aucun sous-titre', (tester) async {
      await openLanguages(
        tester,
        state: const PlaybackState(
          status: PlaybackStatus.playing,
          duration: Duration(minutes: 40),
        ),
      );

      await tester.tap(find.text('Français'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Cette source ne contient aucun sous-titre'),
        findsOneWidget,
      );
      await _leave(tester);
    });
  });

  testWidgets('un clic sur la vidéo affiche les commandes', (tester) async {
    await _pump(tester, _target(ContentKind.movie));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Pause'), findsNothing);

    await tester.tapAt(const Offset(960, 300));
    await tester.pump();
    await tester.pump();

    expect(find.text('Pause'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'PlayerAction');

    // Les commandes repartent ensuite d'elles-mêmes.
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Pause'), findsNothing);
    await _leave(tester);
  });

  testWidgets('la croix en haut à gauche quitte la lecture', (tester) async {
    await _pump(tester, _target(ContentKind.movie));

    final close = find.byIcon(Icons.close);
    expect(tester.getCenter(close).dx, lessThan(300));
    expect(tester.getCenter(close).dy, lessThan(200));

    await tester.tap(close);
    await tester.pump();
    await tester.pump();

    expect(find.text('Pause'), findsNothing);
    await _leave(tester);
  });

  testWidgets('en direct, la croix est à gauche et l heure à droite', (
    tester,
  ) async {
    await _pump(tester, _target(ContentKind.live));

    expect(tester.getCenter(find.byIcon(Icons.close)).dx, lessThan(300));
    final clock = find.textContaining(RegExp(r'^\d\d:\d\d$'));
    expect(tester.getCenter(clock).dx, greaterThan(1500));
    await _leave(tester);
  });

  testWidgets('la fin d un film ne revient qu une seule fois en arrière', (
    tester,
  ) async {
    var backsReachingHome = 0;
    final engine = await _pump(
      tester,
      _target(ContentKind.movie),
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) backsReachingHome++;
        },
        child: const SizedBox.shrink(),
      ),
    );

    // Le moteur émet encore la durée et les pistes après la fin du flux.
    const ended = PlaybackState(status: PlaybackStatus.ended);
    engine
      ..emit(ended)
      ..emit(ended)
      ..emit(ended);
    await tester.pump();
    await tester.pump();

    expect(find.text('Pause'), findsNothing);
    expect(backsReachingHome, 0);
    await _leave(tester);
  });

  testWidgets('le curseur règle le volume', (tester) async {
    final engine = await _pump(tester, _target(ContentKind.movie));

    // La rangée peut être réduite pour tenir sur une ligne.
    final icon = find.byIcon(Icons.volume_up);
    final scale = tester.getRect(icon).width / 22;
    await tester.tapAt(tester.getCenter(icon) + Offset((21 + 65) * scale, 0));
    await tester.pump();

    expect(engine.volumes.single, closeTo(50, 2));
    await _leave(tester);
  });

  testWidgets('une autre version reprend à la même position', (tester) async {
    final next = _target(ContentKind.movie, title: 'Lagon VF');
    await _pump(
      tester,
      _target(
        ContentKind.movie,
        versions: (_, _) async => [
          PlayerVersion(label: 'EN', open: () async => null),
          PlayerVersion(label: 'FR', open: () async => next),
        ],
      ),
    );

    await tester.tap(find.text('Version'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('FR'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Lagon VF'), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('signale l absence d autre version', (tester) async {
    await _pump(
      tester,
      _target(ContentKind.movie, versions: (_, _) async => const []),
    );

    await tester.tap(find.text('Version'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Aucune autre version disponible'), findsOneWidget);
    await _leave(tester);
  });

  for (final language in AppLocalizations.supportedLocales) {
    for (final window in const [Size(1920, 1080), Size(1024, 768)]) {
      final code = language.languageCode;
      testWidgets('la barre d un épisode tient dans l écran ($code, $window)', (
        tester,
      ) async {
        await _pump(
          tester,
          _episode(next: _target(ContentKind.series)),
          language: code,
          window: window,
          state: _playingAt(const Duration(minutes: 1)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        final l10n = lookupAppLocalizations(language);
        final lines = {
          for (final label in [
            l10n.playerPause,
            l10n.playerSkipIntro,
            l10n.playerNextEpisode,
          ])
            tester.getCenter(find.text(label)).dy.round(),
        };
        expect(lines, hasLength(1));
        await _leave(tester);
      });

      testWidgets('la barre tient dans l écran ($code, $window)', (
        tester,
      ) async {
        await _pump(
          tester,
          _target(ContentKind.movie, versions: (_, _) async => const []),
          language: code,
          window: window,
        );
        expect(tester.takeException(), isNull);

        // Une seule ligne de commandes, quelle que soit la langue.
        final l10n = lookupAppLocalizations(language);
        final lines = {
          for (final label in [
            l10n.playerPause,
            l10n.playerVersion,
            l10n.playerExternal,
            l10n.playerAudio,
            l10n.playerSubtitles,
          ])
            tester.getCenter(find.text(label)).dy.round(),
        };
        expect(lines, hasLength(1));
        await _leave(tester);
      });
    }
  }
}
