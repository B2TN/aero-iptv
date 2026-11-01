import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';
import '../../../app/platform/external_player.dart';
import '../../../app/platform/window_fullscreen.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_canvas.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/aero_states.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/focus_frame.dart';
import '../../../focus/dpad_shortcuts.dart';
import '../../../focus/focus_guard.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/language_names.dart';
import '../player_target.dart';

const Duration _overlayDuration = Duration(seconds: 5);
const Duration _noticeDuration = Duration(seconds: 4);
const Duration _seekStep = Duration(seconds: 30);

/// Attente avant d'appliquer un saut : plusieurs appuis n'en font qu'un.
const Duration _seekDelay = Duration(milliseconds: 350);

/// Temps laissé au moteur pour rejoindre la position demandée.
const Duration _seekSettle = Duration(seconds: 4);

/// Le moteur s'arrête sur une image clé, parfois à quelques secondes de la cible.
const Duration _seekTolerance = Duration(seconds: 6);

/// Une fin de film atteinte d'un saut fermerait le lecteur par surprise.
const Duration _seekEndMargin = Duration(seconds: 1);

/// Code renvoyé par les panneaux quand toutes les connexions sont occupées.
const int _connectionsFull = 458;

/// Un panneau met un moment à libérer une connexion fermée : après un changement
/// de chaîne, un compte limité à une connexion serait refusé sans raison.
const int _maxConnectionRetries = 3;
const Duration _connectionRetryDelay = Duration(seconds: 3);

/// Aucune donnée ne dit où finit une intro. Elle est presque toujours dans ces
/// premières minutes, et le saut couvre la plupart des génériques.
const Duration _introWindow = Duration(minutes: 5);
const Duration _introSkip = Duration(seconds: 85);

/// Générique de fin : l'épisode suivant se propose sans ouvrir les commandes.
const Duration _creditsWindow = Duration(seconds: 90);

const double _maxVolume = 100;
const double _seekBarHeight = 36;

String _two(int number) => number.toString().padLeft(2, '0');

String _timeOfDay(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

String _formatTime(Duration value) {
  final hours = value.inHours;
  final minutes = _two(value.inMinutes.remainder(60));
  final seconds = _two(value.inSeconds.remainder(60));
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// Action proposée sur la vidéo, sans ouvrir les commandes.
enum _EpisodeAction { skipIntro, nextEpisode }

/// Écran de lecture.
///
/// Il possède le moteur vidéo : quitter l'écran libère libmpv et ses tampons.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({required this.target, super.key});

  final PlayerTarget target;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlaybackEngine _engine = ref.read(playbackEngineFactoryProvider)();
  late final PlaybackSession _session = PlaybackSession(
    engine: _engine,
    progress: ref.read(watchProgressRepositoryProvider),
    subtitles: ref.read(subtitleRepositoryProvider),
    onSubtitleFailure: (_) {
      if (mounted) _showNotice(context.l10n.playerSubtitlesFailed);
    },
  );
  final FocusNode _rootNode = FocusNode(debugLabel: 'Player');
  final FocusNode _firstAction = FocusNode(debugLabel: 'PlayerAction');
  final FocusNode _seekNode = FocusNode(debugLabel: 'PlayerSeekBar');

  /// Distinct de [_firstAction] : un nœud repris par un autre bouton garde son
  /// focus sans le signaler, et le nouveau bouton n'afficherait pas son halo.
  final FocusNode _failureAction = FocusNode(debugLabel: 'PlayerFailure');
  final WindowFullscreen? _fullscreen = Platform.isWindows
      ? WindowFullscreen()
      : null;

  /// Sous-titre affiché. Une réplique ne reconstruit pas le reste de l'écran.
  final ValueNotifier<String> _cue = ValueNotifier('');
  StreamSubscription<PlaybackState>? _states;
  StreamSubscription<String>? _cues;
  Timer? _hideTimer;
  Timer? _noticeTimer;
  Timer? _seekTimer;
  Timer? _retryTimer;
  PlaybackState _state = const PlaybackState();

  /// Position visée, affichée tant que le moteur ne l'a pas rejointe.
  Duration? _seekTarget;
  bool _seekSent = false;
  bool _overlayVisible = true;

  /// La surcouche s'ouvre sur la barre de temps, après un saut.
  bool _focusSeekBar = false;

  /// La fin du film a déjà demandé le retour à l'écran précédent.
  bool _closing = false;

  /// Épisode qui suit, connu peu après l'ouverture.
  PlayerTarget? _next;
  bool _introSkipped = false;

  /// Flux en cours, interrogé directement si son ouverture échoue.
  ResolvedStream? _stream;

  /// Réponse du serveur à ce flux, connue seulement après un échec.
  StreamProbeResult? _serverAnswer;

  /// Entre un échec et son explication : un nouvel essai est peut-être en cours.
  bool _explaining = false;
  int _connectionRetries = 0;
  double _volume = _maxVolume;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _states = _session.states.listen(_onState);
    _cues = _session.subtitleCues.listen((text) => _cue.value = text);
    // La clé DeepL sort du coffre de façon asynchrone, parfois après ce point.
    ref.listenManual(
      subtitleTranslatorProvider,
      (_, translator) => _session.translator = translator,
      fireImmediately: true,
    );
    ref.listenManual(
      subtitleRepositoryProvider,
      (_, subtitles) => _session.subtitles = subtitles,
    );
    unawaited(_start());
    unawaited(_findNext());
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _noticeTimer?.cancel();
    _seekTimer?.cancel();
    _retryTimer?.cancel();
    _fullscreen?.exit();
    unawaited(_states?.cancel());
    unawaited(_cues?.cancel());
    unawaited(_session.close());
    _cue.dispose();
    _rootNode.dispose();
    _firstAction.dispose();
    _seekNode.dispose();
    _failureAction.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final target = widget.target;
    final item = target.item;
    final settings = ref.read(settingsProvider);
    try {
      final stream = await ref.read(resolveStreamUrlProvider)(
        item.sourceId,
        item.locator,
      );
      _stream = stream;
      await _session.play(
        PlaybackRequest(
          stream: stream,
          isLive: target.isLive,
          liveDelaySeconds: settings.liveDelaySeconds,
          startAt: target.resumeAt,
        ),
        item,
        preferredLanguage: settings.languageCode,
      );
    } on Failure {
      if (mounted) _apply(const PlaybackState(status: PlaybackStatus.failed));
    }
  }

  /// Sans lui, le lecteur reste utilisable : le bouton n'apparaît simplement pas.
  Future<void> _findNext() async {
    try {
      final next = await widget.target.next?.call(ref);
      if (mounted && next != null) setState(() => _next = next);
    } on Failure {
      return;
    }
  }

  void _onState(PlaybackState state) {
    if (!mounted) return;
    final finished = state.status == PlaybackStatus.ended;
    _apply(state);
    if (!finished || widget.target.isLive || _closing) return;
    // Le moteur émet encore des états après la fin : chaque retour de plus
    // remonterait l'accueil, jusqu'à quitter l'application.
    _closing = true;
    Navigator.of(context).maybePop();
  }

  /// En cas d'échec, le bouton du message est la seule issue : il reçoit le
  /// focus, et la surcouche disparue ne doit plus le reprendre.
  void _apply(PlaybackState state) {
    final failedNow =
        state.status == PlaybackStatus.failed &&
        _state.status != PlaybackStatus.failed;
    final target = _seekTarget;
    final reached =
        _seekSent &&
        target != null &&
        (state.position - target).abs() < _seekTolerance;
    if (reached) _seekTimer?.cancel();
    setState(() {
      _state = state;
      if (reached) _seekTarget = null;
      _explaining = state.status == PlaybackStatus.failed && _explaining;
      if (failedNow) _explaining = true;
    });
    if (!failedNow) return;
    _hideTimer?.cancel();
    unawaited(_askServer());
  }

  /// mpv ne dit que « Failed to open », et FFmpeg ne journalise même pas un
  /// refus 401 : seul le serveur peut donner la raison d'un échec.
  Future<void> _askServer() async {
    final stream = _stream;
    final answer = stream == null
        ? null
        : await ref.read(streamProbeProvider).probe(stream);
    if (!mounted) return;
    if (answer?.status == _connectionsFull &&
        _connectionRetries < _maxConnectionRetries) {
      _connectionRetries++;
      _retryTimer = Timer(_connectionRetryDelay, () {
        _scheduleHide();
        unawaited(_start());
      });
      return;
    }
    setState(() {
      _serverAnswer = answer;
      _explaining = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _failureAction.requestFocus();
    });
  }

  /// Réponse du serveur, sans l'adresse complète : elle contient le mot de passe.
  String? _describeAnswer(AppLocalizations l10n) {
    final answer = _serverAnswer;
    if (answer == null) return null;
    final status = answer.status;
    if (status == null) return l10n.playerServerSilent;
    final parts = [
      'HTTP $status',
      if (answer.isVideo == false) 'page web',
      if (answer.redirectedTo != null) answer.redirectedTo!,
    ];
    return l10n.playerServerAnswer(parts.join(', '));
  }

  void _showOverlay({bool onSeekBar = false}) {
    setState(() {
      _overlayVisible = true;
      _focusSeekBar = onSeekBar;
    });
    (onSeekBar ? _seekNode : _firstAction).requestFocus();
    _scheduleHide();
  }

  /// Sous Windows, un clic sur la vidéo fait réapparaître les commandes.
  void _onVideoTap() {
    if (_state.status == PlaybackStatus.failed) return;
    _overlayVisible ? _scheduleHide() : _showOverlay();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_overlayDuration, () {
      if (!mounted || _state.status == PlaybackStatus.paused) return;
      setState(() => _overlayVisible = false);
      _rootNode.requestFocus();
    });
  }

  void _showNotice(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _scheduleHide();
    _noticeTimer = Timer(_noticeDuration, () {
      if (mounted) setState(() => _notice = null);
    });
  }

  void _togglePlay() {
    _scheduleHide();
    if (_state.status == PlaybackStatus.paused) {
      unawaited(_engine.play());
    } else {
      unawaited(_engine.pause());
    }
  }

  /// Les sauts s'additionnent : le moteur n'a pas encore rejoint le précédent.
  void _seekBy(Duration offset) =>
      _seekTo((_seekTarget ?? _state.position) + offset);

  void _seekTo(Duration position) {
    final last = _state.duration - _seekEndMargin;
    final target = position > last ? last : position;
    _scheduleHide();
    _seekSent = false;
    setState(
      () => _seekTarget = target < Duration.zero ? Duration.zero : target,
    );
    _seekTimer?.cancel();
    _seekTimer = Timer(_seekDelay, _applySeek);
  }

  void _applySeek() {
    final target = _seekTarget;
    if (target == null) return;
    _seekSent = true;
    unawaited(_engine.seek(target));
    _seekTimer = Timer(_seekSettle, () {
      if (mounted) setState(() => _seekTarget = null);
    });
  }

  bool get _canSkipIntro {
    final started =
        _state.status == PlaybackStatus.playing ||
        _state.status == PlaybackStatus.paused;
    return started &&
        !_introSkipped &&
        widget.target.item.kind == ContentKind.series &&
        _state.position < _introWindow;
  }

  void _skipIntro() {
    setState(() => _introSkipped = true);
    _seekBy(_introSkip);
  }

  void _openNext() {
    final next = _next;
    if (next == null) return;
    unawaited(Navigator.of(context).pushReplacement(playerRoute(next)));
  }

  _EpisodeAction? get _floatingAction {
    final remaining = _state.duration - _state.position;
    final inCredits =
        _state.status == PlaybackStatus.playing && remaining <= _creditsWindow;
    if (_next != null && inCredits) return _EpisodeAction.nextEpisode;
    return _canSkipIntro ? _EpisodeAction.skipIntro : null;
  }

  void _run(_EpisodeAction action) => switch (action) {
    _EpisodeAction.skipIntro => _skipIntro(),
    _EpisodeAction.nextEpisode => _openNext(),
  };

  void _setVolume(double level) {
    _scheduleHide();
    setState(() => _volume = level.clamp(0, _maxVolume));
    unawaited(_engine.setVolume(_volume));
  }

  void _toggleFullscreen() {
    _scheduleHide();
    setState(() => _fullscreen?.toggle());
  }

  Future<void> _chooseVersion() async {
    final load = widget.target.versions;
    if (load == null) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final versions = await load(ref, context);
    if (!mounted) return;
    if (versions.length < 2) {
      _showNotice(l10n.playerNoOtherVersion);
      return;
    }
    final choice = await showAeroMenu(
      context,
      title: l10n.playerVersion,
      options: [for (final version in versions) version.label],
    );
    if (choice == null || !mounted) return;
    final target = await versions[choice].open();
    if (!mounted) return;
    if (target == null) {
      _showNotice(l10n.playerVersionMissing);
      return;
    }
    await navigator.pushReplacement(
      playerRoute(
        widget.target.isLive ? target : target.resumingAt(_state.position),
      ),
    );
  }

  Future<void> _openExternally() async {
    final l10n = context.l10n;
    final item = widget.target.item;
    try {
      final stream = await ref.read(resolveStreamUrlProvider)(
        item.sourceId,
        item.locator,
      );
      final opened = await ExternalPlayer.open(stream.url, title: item.title);
      if (!mounted) return;
      if (opened) {
        await _engine.pause();
      } else {
        _showNotice(l10n.playerExternalMissing);
      }
    } on Failure {
      if (mounted) _showNotice(l10n.playerExternalMissing);
    }
  }

  Future<void> _chooseAudio() async {
    final tracks = _state.audioTracks;
    final l10n = context.l10n;
    final choice = await showAeroMenu(
      context,
      title: l10n.playerAudio,
      options: [
        for (final (index, track) in tracks.indexed)
          _audioLabel(l10n, index, track),
      ],
    );
    if (choice != null) await _engine.selectAudio(tracks[choice]);
  }

  Future<void> _chooseSubtitles() async {
    final tracks = _state.subtitleTracks;
    final l10n = context.l10n;
    // Sans aucune clé, rien ne peut être obtenu : l'option n'est pas proposée.
    final canTranslate =
        ref.read(subtitleTranslatorProvider) != null ||
        ref.read(subtitleRepositoryProvider).isAvailable;
    final choice = await showAeroMenu(
      context,
      title: l10n.playerSubtitles,
      options: [
        l10n.playerSubtitlesOff,
        for (final (index, track) in tracks.indexed)
          _trackLabel(l10n.playerTrack(index + 1), track),
        if (canTranslate) l10n.playerSubtitlesDownload,
      ],
    );
    if (choice == null) return;
    if (choice == tracks.length + 1) {
      await _downloadSubtitles();
      return;
    }
    _session.stopSubtitleTranslation();
    await _engine.selectSubtitle(choice == 0 ? null : tracks[choice - 1]);
  }

  Future<void> _downloadSubtitles() async {
    final l10n = context.l10n;
    final appLanguage = ref.read(settingsProvider).languageCode;
    final languages = translationLanguages(appLanguage);
    final choice = await showAeroMenu(
      context,
      title: l10n.playerSubtitlesLanguage,
      options: [
        for (final code in languages) languageName(code, appLanguage) ?? code,
      ],
    );
    if (choice == null || !mounted) return;
    _showNotice(l10n.playerSubtitlesSearching);
    try {
      final result = await _session.downloadSubtitles(
        language: languages[choice],
      );
      if (!mounted) return;
      _showNotice(switch (result) {
        SubtitleDownload.loaded => l10n.playerSubtitlesLoaded,
        SubtitleDownload.untranslated => l10n.playerSubtitlesUntranslated,
        SubtitleDownload.imagesOnly => l10n.playerSubtitlesImagesOnly,
        SubtitleDownload.notFound ||
        SubtitleDownload.notConfigured => l10n.playerSubtitlesNotFound,
      });
    } on Failure {
      if (mounted) _showNotice(l10n.playerSubtitlesFailed);
    }
  }

  String? _languageOf(MediaTrack track) => languageName(
    normalizeLanguageCode(track.language),
    ref.read(settingsProvider).languageCode,
  );

  /// Langue et nombre de canaux : « Français (stéréo) ».
  String _audioLabel(AppLocalizations l10n, int index, MediaTrack track) {
    final name =
        _languageOf(track) ??
        track.title ??
        track.language ??
        l10n.playerTrack(index + 1);
    final layout = switch (track.channelCount) {
      null => null,
      1 => l10n.playerMono,
      2 => l10n.playerStereo,
      6 => '5.1',
      8 => '7.1',
      final count => '$count',
    };
    return layout == null ? name : '$name ($layout)';
  }

  String _trackLabel(String fallback, MediaTrack track) {
    final name = _languageOf(track);
    final title = track.title;
    if (name != null) return title == null ? name : '$name ($title)';
    return title ?? track.language ?? fallback;
  }

  /// Tant que la surcouche est masquée, toute touche la fait réapparaître.
  /// Les touches multimédias et de déplacement agissent directement.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _state.status == PlaybackStatus.failed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (!_overlayVisible) {
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack ||
          key == LogicalKeyboardKey.gameButtonB) {
        return KeyEventResult.ignored;
      }
      final action = _floatingAction;
      if (action != null && isConfirmKey(key)) {
        _run(action);
        return KeyEventResult.handled;
      }
      final isArrow =
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight;
      if (isArrow && !widget.target.isLive && _state.duration > Duration.zero) {
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final forward = (key == LogicalKeyboardKey.arrowRight) != isRtl;
        _showOverlay(onSeekBar: true);
        _seekBy(forward ? _seekStep : -_seekStep);
        return KeyEventResult.handled;
      }
      _showOverlay();
      return KeyEventResult.handled;
    }
    _scheduleHide();
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final surface = ref.watch(videoSurfaceBuilderProvider);
    final l10n = context.l10n;
    final failed = _state.status == PlaybackStatus.failed;
    final connectionsFull = _serverAnswer?.status == _connectionsFull;
    final detail = _state.failureDetail;
    final fullscreen = _fullscreen;
    final isLive = widget.target.isLive;
    final floating = _floatingAction;
    return FocusGuard(
      fallback: () => _rootNode,
      child: Focus(
        focusNode: _rootNode,
        onKeyEvent: _onKeyEvent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF000000)),
            RepaintBoundary(child: surface(_engine)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onVideoTap,
            ),
            AeroScale(
              child: _SubtitleLine(cue: _cue, raised: _overlayVisible),
            ),
            AeroScale(
              child: _explaining
                  ? AeroLoading(label: l10n.playerConnecting)
                  : failed
                  ? AeroMessage(
                      title: connectionsFull
                          ? l10n.playerConnectionsFullTitle
                          : l10n.playerFailedTitle,
                      body: [
                        if (connectionsFull)
                          l10n.playerConnectionsFullBody
                        else ...[
                          l10n.playerFailedBody,
                          ?detail,
                        ],
                        ?_describeAnswer(l10n),
                      ].join('\n\n'),
                      actionLabel: l10n.actionBack,
                      onAction: () => Navigator.of(context).maybePop(),
                      focusNode: _failureAction,
                    )
                  : _overlayVisible
                  ? _Overlay(
                      title: widget.target.item.title,
                      state: _state,
                      position: _seekTarget ?? _state.position,
                      isLive: isLive,
                      notice: _notice,
                      volume: Platform.isWindows ? _volume : null,
                      firstAction: _firstAction,
                      seekNode: _seekNode,
                      focusSeekBar: _focusSeekBar,
                      onSeekStep: (forward) =>
                          _seekBy(forward ? _seekStep : -_seekStep),
                      onSeek: _seekTo,
                      onClose: () => Navigator.of(context).maybePop(),
                      onTogglePlay: _togglePlay,
                      onVolume: _setVolume,
                      onVersion: widget.target.versions == null
                          ? null
                          : _chooseVersion,
                      onExternal: _openExternally,
                      onAudio: !isLive && _state.audioTracks.length > 1
                          ? _chooseAudio
                          : null,
                      onSubtitles: isLive ? null : _chooseSubtitles,
                      onSkipIntro: _canSkipIntro ? _skipIntro : null,
                      onNextEpisode: _next == null ? null : _openNext,
                      fullscreen: fullscreen?.isActive,
                      onFullscreen: _toggleFullscreen,
                    )
                  : floating != null
                  ? _FloatingAction(
                      label: switch (floating) {
                        _EpisodeAction.skipIntro => l10n.playerSkipIntro,
                        _EpisodeAction.nextEpisode => l10n.playerNextEpisode,
                      },
                      onSelect: () => _run(floating),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton posé sur la vidéo. Il ne prend pas le focus : la touche de validation
/// l'active tant que les commandes sont fermées, comme sur Netflix.
class _FloatingAction extends StatelessWidget {
  const _FloatingAction({required this.label, required this.onSelect});

  final String label;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.bottomEnd,
    child: Padding(
      // Au-dessus des sous-titres, qui peuvent occuper toute la largeur.
      padding: const EdgeInsetsDirectional.only(
        end: AeroMetrics.pagePadding,
        bottom: 110,
      ),
      child: ExcludeFocus(
        child: AeroButton(
          label: label,
          icon: Icons.skip_next,
          onSelect: onSelect,
        ),
      ),
    ),
  );
}

/// Réplique en cours. Le contour remplace une ombre floue, coûteuse à dessiner
/// sur un stick à chaque changement de texte.
class _SubtitleLine extends StatelessWidget {
  const _SubtitleLine({required this.cue, required this.raised});

  final ValueListenable<String> cue;

  /// La barre de commandes est affichée : le texte passe au-dessus.
  final bool raised;

  static const TextStyle _style = TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.25,
    shadows: [
      Shadow(color: Color(0xFF000000), offset: Offset(1.5, 1.5)),
      Shadow(color: Color(0xFF000000), offset: Offset(-1.5, 1.5)),
      Shadow(color: Color(0xFF000000), offset: Offset(1.5, -1.5)),
      Shadow(color: Color(0xFF000000), offset: Offset(-1.5, -1.5)),
    ],
  );

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(80, 0, 80, raised ? 236 : 44),
        child: ValueListenableBuilder<String>(
          valueListenable: cue,
          builder: (context, text, _) =>
              Text(text, style: _style, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}

/// Piste d'un curseur : la partie parcourue et son bouton.
class _SliderTrack extends StatelessWidget {
  const _SliderTrack({
    required this.width,
    required this.fraction,
    required this.color,
  });

  final double width;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    alignment: AlignmentDirectional.centerStart,
    children: [
      SizedBox(
        width: width,
        height: 6,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0x33E8FBFF),
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ),
      SizedBox(
        width: width * fraction,
        height: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ),
      PositionedDirectional(
        start: width * fraction - 9,
        child: SizedBox(
          width: 18,
          height: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AeroColors.foam),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Barre de temps : un clic y place la lecture, les flèches sautent de 30 s.
class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.waitingLabel,
    required this.focusNode,
    required this.autofocus,
    required this.onStep,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;

  /// Remplace le temps écoulé tant que le flux n'a pas démarré.
  final String? waitingLabel;
  final FocusNode focusNode;
  final bool autofocus;

  /// `true` pour avancer, `false` pour reculer.
  final ValueChanged<bool> onStep;
  final ValueChanged<Duration> onSeek;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _focused = false;

  /// Position suivie pendant un glissement, appliquée au relâchement.
  double? _dragged;

  bool get _enabled => widget.duration > Duration.zero;

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  @override
  void initState() {
    super.initState();
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  double _fractionAt(double x, double width) {
    final fraction = (x / width).clamp(0.0, 1.0);
    return _isRtl ? 1 - fraction : fraction;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_enabled) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.arrowLeft &&
        key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    widget.onStep((key == LogicalKeyboardKey.arrowRight) != _isRtl);
    return KeyEventResult.handled;
  }

  Widget _buildTrack(double width, double fraction, Color color) {
    void seekTo(double x) {
      widget.focusNode.requestFocus();
      widget.onSeek(widget.duration * _fractionAt(x, width));
    }

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _enabled
            ? (details) => seekTo(details.localPosition.dx)
            : null,
        onHorizontalDragUpdate: _enabled
            ? (details) => setState(
                () => _dragged = _fractionAt(details.localPosition.dx, width),
              )
            : null,
        onHorizontalDragEnd: _enabled
            ? (_) {
                final dragged = _dragged;
                setState(() => _dragged = null);
                if (dragged != null) {
                  widget.focusNode.requestFocus();
                  widget.onSeek(widget.duration * dragged);
                }
              }
            : null,
        child: SizedBox(
          width: width,
          height: _seekBarHeight,
          child: _SliderTrack(width: width, fraction: fraction, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds;
    final dragged = _dragged;
    final fraction =
        dragged ??
        (total == 0
            ? 0.0
            : (widget.position.inMilliseconds / total).clamp(0.0, 1.0));
    final shown = dragged == null ? widget.position : widget.duration * dragged;
    final color = _focused ? AeroColors.leaf : AeroColors.aqua;
    return Focus(
      focusNode: widget.focusNode,
      canRequestFocus: _enabled,
      onKeyEvent: _onKeyEvent,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Semantics(
        slider: true,
        value: _formatTime(shown),
        child: FocusFrame(
          focused: _focused,
          scale: 1,
          halo: HaloShape.pill,
          child: SizedBox(
            height: _seekBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Text(
                    widget.waitingLabel ?? _formatTime(shown),
                    style: AeroText.body,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) =>
                          _buildTrack(constraints.maxWidth, fraction, color),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(_formatTime(widget.duration), style: AeroText.body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Curseur de volume, à la souris comme au clavier.
class _VolumeSlider extends StatefulWidget {
  const _VolumeSlider({required this.level, required this.onChanged});

  final double level;
  final ValueChanged<double> onChanged;

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  static const double _trackWidth = 130;
  static const double _keyStep = 5;

  bool _focused = false;

  void _setFromPosition(double x) =>
      widget.onChanged((x / _trackWidth * _maxVolume).clamp(0, _maxVolume));

  /// Aux extrémités, la flèche redevient un déplacement du focus.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final level = widget.level;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && level > 0) {
      widget.onChanged(level - _keyStep);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        level < _maxVolume) {
      widget.onChanged(level + _keyStep);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final color = _focused ? AeroColors.leaf : AeroColors.aqua;
    return Focus(
      onKeyEvent: _onKeyEvent,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: SizedBox(
        height: 48,
        child: Padding(
          // Le bouton du curseur dépasse de sa piste aux extrémités.
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.level == 0 ? Icons.volume_off : Icons.volume_up,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 10),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      _setFromPosition(details.localPosition.dx),
                  onHorizontalDragUpdate: (details) =>
                      _setFromPosition(details.localPosition.dx),
                  child: SizedBox(
                    width: _trackWidth,
                    height: 48,
                    child: _SliderTrack(
                      width: _trackWidth,
                      fraction: widget.level / _maxVolume,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Heure courante, et heure de fin d'une VOD. L'heure courante se met à jour
/// seule, à chaque changement de minute.
class _Clock extends StatefulWidget {
  const _Clock({this.endsAt});

  final String? endsAt;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    final seconds = 60 - DateTime.now().second;
    _timer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) {
    final endsAt = widget.endsAt;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_timeOfDay(DateTime.now()), style: AeroText.heading),
          if (endsAt != null) Text(endsAt, style: AeroText.caption),
        ],
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.title,
    required this.state,
    required this.position,
    required this.isLive,
    required this.notice,
    required this.volume,
    required this.firstAction,
    required this.seekNode,
    required this.focusSeekBar,
    required this.onSeekStep,
    required this.onSeek,
    required this.onClose,
    required this.onTogglePlay,
    required this.onVolume,
    required this.onVersion,
    required this.onExternal,
    required this.onAudio,
    required this.onSubtitles,
    required this.onSkipIntro,
    required this.onNextEpisode,
    required this.fullscreen,
    required this.onFullscreen,
  });

  final String title;
  final PlaybackState state;

  /// Position affichée : celle du moteur, ou celle d'un saut en cours.
  final Duration position;
  final bool isLive;
  final String? notice;

  /// `null` sur les plateformes sans réglage de volume dans le lecteur.
  final double? volume;
  final FocusNode firstAction;
  final FocusNode seekNode;
  final bool focusSeekBar;
  final ValueChanged<bool> onSeekStep;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onClose;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onVolume;
  final VoidCallback? onVersion;
  final VoidCallback onExternal;
  final VoidCallback? onAudio;
  final VoidCallback? onSubtitles;
  final VoidCallback? onSkipIntro;
  final VoidCallback? onNextEpisode;

  /// `null` sur les plateformes sans plein écran à piloter.
  final bool? fullscreen;
  final VoidCallback onFullscreen;

  List<Widget> _buildActions(AppLocalizations l10n, {required bool paused}) {
    final level = volume;
    return [
      AeroButton(
        label: paused ? l10n.playerPlay : l10n.playerPause,
        icon: paused ? Icons.play_arrow : Icons.pause,
        focusNode: firstAction,
        autofocus: !focusSeekBar,
        onSelect: onTogglePlay,
      ),
      if (level != null) _VolumeSlider(level: level, onChanged: onVolume),
      if (onVersion != null)
        AeroButton(label: l10n.playerVersion, onSelect: onVersion),
      AeroButton(label: l10n.playerExternal, onSelect: onExternal),
      if (onAudio != null)
        AeroButton(label: l10n.playerAudio, onSelect: onAudio),
      if (onSubtitles != null)
        AeroButton(label: l10n.playerSubtitles, onSelect: onSubtitles),
      if (onSkipIntro != null)
        AeroButton(label: l10n.playerSkipIntro, onSelect: onSkipIntro),
      if (onNextEpisode != null)
        AeroButton(
          label: l10n.playerNextEpisode,
          icon: Icons.skip_next,
          onSelect: onNextEpisode,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paused = state.status == PlaybackStatus.paused;
    final waiting =
        state.status == PlaybackStatus.opening ||
        state.status == PlaybackStatus.buffering;
    final remaining = state.duration - position;
    final actions = _buildActions(l10n, paused: paused);
    final inFullscreen = fullscreen;
    final message = notice;
    return Padding(
      padding: const EdgeInsets.all(AeroMetrics.pagePadding),
      child: Stack(
        children: [
          Align(
            alignment: AlignmentDirectional.topStart,
            child: Semantics(
              label: l10n.playerClose,
              child: AeroButton(
                label: '',
                icon: Icons.close,
                onSelect: onClose,
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: _Clock(
              endsAt: !isLive && !waiting && remaining > Duration.zero
                  ? l10n.playerEndsAt(_timeOfDay(DateTime.now().add(remaining)))
                  : null,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message != null) ...[
                  Center(
                    child: GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(message, style: AeroText.body),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isLive) ...[
                        Text(
                          title,
                          style: AeroText.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        _SeekBar(
                          position: position,
                          duration: state.duration,
                          waitingLabel: waiting ? l10n.loading : null,
                          focusNode: seekNode,
                          autofocus: focusSeekBar,
                          onStep: onSeekStep,
                          onSeek: onSeek,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          // Une seule ligne, toujours : si les libellés ne
                          // tiennent pas, les commandes rétrécissent ensemble.
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final (index, action) in actions.indexed)
                                    Padding(
                                      padding: EdgeInsetsDirectional.only(
                                        start: index == 0 ? 0 : 12,
                                      ),
                                      child: action,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (inFullscreen != null) ...[
                            const SizedBox(width: 12),
                            Semantics(
                              label: inFullscreen
                                  ? l10n.playerExitFullscreen
                                  : l10n.playerFullscreen,
                              child: AeroButton(
                                label: '',
                                icon: inFullscreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                                onSelect: onFullscreen,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
