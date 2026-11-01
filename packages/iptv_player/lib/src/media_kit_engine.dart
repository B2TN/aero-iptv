import 'dart:async';

import 'package:iptv_domain/iptv_domain.dart';
import 'package:media_kit/media_kit.dart' as mk;

import 'live_buffer_policy.dart';
import 'memory_tier.dart';
import 'mpv_profile.dart';
import 'playback_log_policy.dart';
import 'stream_relay.dart';
import 'track_mapper.dart';

/// Initialise libmpv. À appeler une seule fois, au démarrage de l'application.
///
/// [libmpv] remplace la bibliothèque embarquée, ce qui sert aux tests.
void initializePlaybackEngine({String? libmpv}) =>
    mk.MediaKit.ensureInitialized(libmpv: libmpv);

/// Moteur vidéo basé sur libmpv.
///
/// Une instance correspond à un écran de lecture. Elle peut enchaîner plusieurs
/// flux, puis doit être libérée avec [dispose].
final class MediaKitEngine implements PlaybackEngine {
  MediaKitEngine({MemoryTier tier = MemoryTier.standard})
    : _tier = tier,
      player = mk.Player(
        configuration: mk.PlayerConfiguration(
          title: 'Aero IPTV',
          bufferSize: tier.forwardBytes,
          // Seules les erreurs sont demandées, et leur texte n'est pas gardé.
          logLevel: mk.MPVLogLevel.error,
        ),
      ) {
    final stream = player.stream;
    _subscriptions.addAll([
      stream.position.listen(_onPosition),
      stream.duration.listen(_onDuration),
      stream.playing.listen(_onPlaying),
      stream.buffering.listen(_onBuffering),
      stream.completed.listen(_onCompleted),
      stream.tracks.listen(_onTracks),
      stream.track.listen(_onSelectedTracks),
      stream.log.listen(_onLog),
    ]);
  }

  final MemoryTier _tier;

  /// Lecteur sous-jacent, réservé à `VideoSurface`.
  final mk.Player player;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  PlaybackState _state = const PlaybackState();
  Map<String, mk.AudioTrack> _audioById = const {};
  Map<String, mk.SubtitleTrack> _subtitleById = const {};
  final Set<String> _unreadableAudio = {};
  bool _buffering = false;
  bool _disposed = false;

  /// Relais des flux, créé à la première ouverture.
  StreamRelay? _relay;

  /// Vrai dès que la position avance. `playing` ne suffit pas : media_kit le
  /// passe à vrai dès l'ouverture, avant la moindre donnée reçue.
  bool _started = false;

  @override
  PlaybackState get state => _state;

  @override
  Stream<PlaybackState> get states => _states.stream;

  @override
  Stream<String> get subtitleCues => player.stream.subtitle.map(
    (lines) => lines.where((line) => line.isNotEmpty).join('\n'),
  );

  @override
  Future<void> open(PlaybackRequest request) async {
    _buffering = false;
    _started = false;
    _audioById = const {};
    _subtitleById = const {};
    _unreadableAudio.clear();
    _emit(const PlaybackState(status: PlaybackStatus.opening));

    final native = player.platform! as mk.NativePlayer;
    final options = {
      ...MpvProfile.base(_tier),
      ...LiveBufferPolicy.optionsFor(request, _tier),
    };
    for (final option in options.entries) {
      await native.setProperty(option.key, option.value);
    }

    final stream = request.stream;
    final address = await _addressOf(request);
    if (_disposed) return;
    await player.open(
      mk.Media(
        address,
        // Le relais applique lui-même les en-têtes du flux.
        httpHeaders: address != stream.url || stream.headers.isEmpty
            ? null
            : stream.headers,
        start: request.startAt,
      ),
    );
  }

  /// Le relais n'ouvre qu'une connexion à la fois, et cache au lecteur le mot de
  /// passe du compte.
  Future<String> _addressOf(PlaybackRequest request) async {
    final stream = request.stream;
    if (!StreamRelay.canCarry(stream.url)) return stream.url;
    final relay = _relay ??= await StreamRelay.start(
      windowBytes: _tier.relayWindowBytes,
    );
    // L'écran a pu se fermer pendant le démarrage du relais.
    if (_disposed) {
      relay.close();
      return stream.url;
    }
    return relay.addressOf(stream, live: request.isLive);
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> setVolume(double percent) => player.setVolume(percent);

  @override
  Future<void> selectAudio(MediaTrack track) async {
    final audio = _audioById[track.id];
    if (audio != null) await player.setAudioTrack(audio);
  }

  @override
  Future<void> selectSubtitle(MediaTrack? track) async {
    if (track == null) {
      await player.setSubtitleTrack(mk.SubtitleTrack.no());
      return;
    }
    final subtitle = _subtitleById[track.id];
    if (subtitle != null) await player.setSubtitleTrack(subtitle);
  }

  @override
  Future<void> loadSubtitle(SubtitleFile file) => player.setSubtitleTrack(
    mk.SubtitleTrack.data(
      file.content,
      title: file.title,
      language: file.language,
    ),
  );

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await player.dispose();
    _relay?.close();
    await _states.close();
  }

  /// La position ne change qu'une fois par seconde : l'interface n'a pas à se
  /// reconstruire aux dizaines de mises à jour émises par mpv.
  void _onPosition(Duration position) {
    if (!_started && position > Duration.zero) {
      _started = true;
      _updateStatus();
    }
    if (position.inSeconds != _state.position.inSeconds) {
      _emit(_state.copyWith(position: position));
    }
  }

  void _onDuration(Duration duration) =>
      _emit(_state.copyWith(duration: duration));

  void _onPlaying(bool playing) => _updateStatus();

  void _onBuffering(bool buffering) {
    _buffering = buffering;
    _updateStatus();
  }

  /// Un flux en échec se termine aussi : son message doit rester à l'écran.
  void _onCompleted(bool completed) {
    if (completed && _state.status != PlaybackStatus.failed) {
      _emit(_state.copyWith(status: PlaybackStatus.ended));
    }
  }

  void _onTracks(mk.Tracks tracks) {
    _audioById = {
      for (final track in tracks.audio.where(TrackMapper.isRealAudio))
        track.id: track,
    };
    _subtitleById = {
      for (final track in tracks.subtitle.where(TrackMapper.isRealSubtitle))
        track.id: track,
    };
    final audio = TrackMapper.audio(tracks.audio);
    final hasMedia =
        audio.isNotEmpty ||
        tracks.video.any((track) => track.id != 'auto' && track.id != 'no');
    _emit(
      _state.copyWith(
        tracksReady: hasMedia,
        audioTracks: audio,
        subtitleTracks: TrackMapper.subtitle(tracks.subtitle),
      ),
    );
  }

  void _onSelectedTracks(mk.Track track) => _emit(
    _state.copyWith(
      selectedAudioId: track.audio.id,
      selectedSubtitleId: track.subtitle.id,
    ),
  );

  /// Lit le journal plutôt que `stream.error` : ce flux ignore les erreurs
  /// fatales de mpv, et mêle les vraies pannes aux pistes illisibles.
  void _onLog(mk.PlayerLog log) {
    final starting =
        _state.status == PlaybackStatus.opening ||
        _state.status == PlaybackStatus.buffering;
    switch (PlaybackLogPolicy.judge(
      prefix: log.prefix,
      level: log.level,
      text: log.text,
    )) {
      case LogVerdict.fail:
        _fail(log.text);
      case LogVerdict.failWhileStarting when starting:
        _fail(log.text);
      case LogVerdict.tryNextAudioTrack:
        unawaited(_skipUnreadableAudio());
      case LogVerdict.failWhileStarting || LogVerdict.ignore:
        break;
    }
  }

  /// mpv peut continuer après une erreur : un flux abandonné ne doit pas garder
  /// la seule connexion d'un abonnement.
  void _fail(String text) {
    _emit(
      _state.copyWith(
        status: PlaybackStatus.failed,
        failureDetail: PlaybackLogPolicy.detailOf(text),
      ),
    );
    unawaited(player.stop());
    _relay?.release();
  }

  /// Sans cela, un film dont la première piste est en TrueHD resterait muet
  /// alors qu'une piste AC-3 lisible l'accompagne.
  Future<void> _skipUnreadableAudio() async {
    final current = _state.selectedAudioId;
    if (current != null) _unreadableAudio.add(current);
    final next = _audioById.entries
        .where((entry) => !_unreadableAudio.contains(entry.key))
        .firstOrNull;
    if (next != null) await player.setAudioTrack(next.value);
  }

  void _updateStatus() {
    final current = _state.status;
    if (current == PlaybackStatus.ended || current == PlaybackStatus.failed) {
      return;
    }
    final next = _buffering
        ? PlaybackStatus.buffering
        : !_started
        ? PlaybackStatus.opening
        : player.state.playing
        ? PlaybackStatus.playing
        : PlaybackStatus.paused;
    if (next != current) _emit(_state.copyWith(status: next));
  }

  void _emit(PlaybackState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }
}
