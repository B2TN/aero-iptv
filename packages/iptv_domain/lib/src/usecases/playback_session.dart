import 'dart:async';

import '../common/failure.dart';
import '../entities/content_kind.dart';
import '../entities/media_track.dart';
import '../entities/playback_request.dart';
import '../entities/playback_state.dart';
import '../entities/subtitle_outcome.dart';
import '../entities/watch_progress.dart';
import '../normalization/language_code.dart';
import '../ports/playback_engine.dart';
import '../ports/subtitle_translator.dart';
import '../ports/watch_progress_repository.dart';
import 'choose_subtitle.dart';

/// Écart de lecture entre deux enregistrements de la position.
const Duration _saveInterval = Duration(seconds: 15);

/// Langue des sous-titres que l'on sait presque toujours trouver.
const String _sourceLanguage = 'en';

/// Pistes dessinées en images : elles ne contiennent aucun texte à traduire.
const Set<String> _imageSubtitleCodecs = {
  'hdmv_pgs_subtitle',
  'pgssub',
  'dvd_subtitle',
  'dvdsub',
  'dvb_subtitle',
  'dvbsub',
  'xsub',
};

/// Piste réduite aux passages en langue étrangère : elle ne suit pas le film.
const String _forcedTrackMark = 'forced';

/// Au-delà de cette part du contenu, il est considéré comme terminé.
const double _finishedRatio = 0.95;

/// Pilote une lecture : sous-titres automatiques et position de reprise.
final class PlaybackSession {
  PlaybackSession({
    required PlaybackEngine engine,
    required WatchProgressRepository progress,
    this.translator,
    void Function(Failure failure)? onSubtitleFailure,
    ChooseSubtitle chooseSubtitle = const ChooseSubtitle(),
    DateTime Function() clock = DateTime.now,
  }) : _engine = engine,
       _progress = progress,
       _onSubtitleFailure = onSubtitleFailure,
       _chooseSubtitle = chooseSubtitle,
       _clock = clock;

  final PlaybackEngine _engine;
  final WatchProgressRepository _progress;

  /// Service de traduction. Il peut changer après le début de la lecture : sa
  /// clé est lue dans le coffre de façon asynchrone.
  SubtitleTranslator? translator;
  final void Function(Failure failure)? _onSubtitleFailure;
  final ChooseSubtitle _chooseSubtitle;
  final DateTime Function() _clock;

  final StreamController<String> _cues = StreamController<String>.broadcast();
  final Map<String, String> _translatedCues = {};
  StreamSubscription<PlaybackState>? _subscription;
  StreamSubscription<String>? _cueSubscription;
  bool _translatingCues = false;
  String _currentCue = '';
  PlaybackItem? _item;
  String _language = 'fr';

  /// Langue choisie pour traduire les répliques.
  String _cueLanguage = 'fr';
  bool _subtitlesHandled = false;
  Duration _lastSaved = Duration.zero;

  /// État de la lecture, pour l'interface.
  Stream<PlaybackState> get states => _engine.states;

  /// Sous-titre à afficher, traduit si la traduction est active.
  Stream<String> get subtitleCues => _cues.stream;

  /// Démarre [item]. Peut être rappelé pour passer à une autre chaîne.
  Future<void> play(
    PlaybackRequest request,
    PlaybackItem item, {
    required String preferredLanguage,
  }) async {
    await _saveProgress();
    _item = item;
    _language = preferredLanguage;
    // Le direct ne reçoit pas de sous-titres choisis d'office.
    _subtitlesHandled = item.kind == ContentKind.live;
    _lastSaved = request.startAt ?? Duration.zero;
    _translatingCues = false;
    _translatedCues.clear();
    _subscription ??= _engine.states.listen(_onState);
    _cueSubscription ??= _engine.subtitleCues.listen(_onCue);
    await _engine.open(request);
  }

  /// Arrête la traduction, quand l'utilisateur choisit une autre piste.
  void stopSubtitleTranslation() => _translatingCues = false;

  /// Pistes de texte du flux, les pistes complètes d'abord écartant les autres.
  List<MediaTrack> get _textTracks {
    final text = _engine.state.subtitleTracks
        .where((track) => !_imageSubtitleCodecs.contains(track.codec))
        .toList(growable: false);
    final complete = text
        .where(
          (track) =>
              !(track.title?.toLowerCase().contains(_forcedTrackMark) ?? false),
        )
        .toList(growable: false);
    return complete.isEmpty ? text : complete;
  }

  MediaTrack? _textTrackIn(String language) => _textTracks
      .where((track) => normalizeLanguageCode(track.language) == language)
      .firstOrNull;

  /// Traduit à la volée la meilleure piste de texte du flux, l'anglais d'abord.
  ///
  /// Le texte complet d'une piste n'est pas accessible sans lire tout le fichier :
  /// chaque réplique est donc traduite au moment où elle arrive.
  Future<void> _translateEmbeddedTrack(String language) async {
    final source = _textTrackIn(_sourceLanguage) ?? _textTracks.first;
    if (language != _cueLanguage) {
      _cueLanguage = language;
      _translatedCues.clear();
    }
    _translatingCues = true;
    await _engine.selectSubtitle(source);
    // La piste est peut-être déjà affichée : mpv ne renverrait pas la réplique.
    if (_currentCue.isNotEmpty) _onCue(_currentCue);
  }

  void _onCue(String text) {
    _currentCue = text;
    final translator = this.translator;
    if (!_translatingCues || translator == null || text.trim().isEmpty) {
      _cues.add(text);
      return;
    }
    final known = _translatedCues[text];
    if (known != null) {
      _cues.add(known);
    } else {
      unawaited(_translateCue(translator, text));
    }
  }

  Future<void> _translateCue(SubtitleTranslator translator, String text) async {
    try {
      final translated = await translator.translateTexts([
        text,
      ], language: _cueLanguage);
      _translatedCues[text] = translated.single;
      if (_currentCue == text && !_cues.isClosed) _cues.add(translated.single);
    } on Failure catch (failure) {
      _translatingCues = false;
      _onSubtitleFailure?.call(failure);
      if (_currentCue == text && !_cues.isClosed) _cues.add(text);
    }
  }

  /// Affiche les sous-titres dans [language], par défaut la langue de
  /// l'utilisateur.
  ///
  /// Une piste du flux déjà dans cette langue passe d'abord. Sinon, la
  /// meilleure piste de texte du flux est traduite à la volée, si un service
  /// de traduction est configuré.
  Future<SubtitleOutcome> showSubtitles({String? language}) async {
    if (_item == null) return SubtitleOutcome.none;
    final target = language ?? _language;
    final exact = _textTrackIn(target);
    if (exact != null) {
      _translatingCues = false;
      await _engine.selectSubtitle(exact);
      return SubtitleOutcome.loaded;
    }
    if (translator != null && _textTracks.isNotEmpty) {
      await _translateEmbeddedTrack(target);
      return SubtitleOutcome.loaded;
    }
    return _textTracks.isEmpty && _engine.state.subtitleTracks.isNotEmpty
        ? SubtitleOutcome.imagesOnly
        : SubtitleOutcome.none;
  }

  /// Enregistre la position, puis libère le moteur.
  Future<void> close() async {
    await _saveProgress();
    await _subscription?.cancel();
    await _cueSubscription?.cancel();
    _subscription = null;
    _cueSubscription = null;
    _item = null;
    await _cues.close();
    await _engine.dispose();
  }

  void _onState(PlaybackState state) {
    final item = _item;
    if (item == null) return;
    if (!_subtitlesHandled && state.tracksReady) {
      _subtitlesHandled = true;
      unawaited(_applySubtitles(item, state));
    }
    if (state.position - _lastSaved >= _saveInterval) {
      unawaited(_saveProgress());
    }
  }

  Future<void> _applySubtitles(PlaybackItem item, PlaybackState state) async {
    final choice = _chooseSubtitle(
      audioTracks: state.audioTracks,
      subtitleTracks: state.subtitleTracks,
      selectedAudioId: state.selectedAudioId,
      preferredLanguage: _language,
    );
    switch (choice) {
      case SubtitlesNotNeeded() || SubtitlesMissing():
        break;
      case UseEmbeddedSubtitles():
        await _engine.selectSubtitle(choice.track);
    }
  }

  Future<void> _saveProgress() async {
    final item = _item;
    if (item == null || item.kind == ContentKind.live) return;
    final state = _engine.state;
    if (state.duration == Duration.zero) return;

    final position = state.position;
    _lastSaved = position;
    final finished =
        state.status == PlaybackStatus.ended ||
        position.inMilliseconds >=
            state.duration.inMilliseconds * _finishedRatio;
    if (finished) {
      await _progress.remove(item.sourceId, item.contentKey);
      return;
    }
    await _progress.save(
      WatchProgress(
        sourceId: item.sourceId,
        contentKey: item.contentKey,
        kind: item.kind,
        title: item.title,
        posterUrl: item.posterUrl,
        position: position,
        duration: state.duration,
        updatedAt: _clock(),
        locator: item.locator,
      ),
    );
  }
}
