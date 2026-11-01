import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:iptv_domain/iptv_domain.dart';

/// Code renvoyé par les panneaux quand toutes les connexions sont occupées.
const int _connectionsFull = 458;

/// Temps laissé au panneau pour libérer la connexion qui vient d'être coupée.
/// Il reste inférieur au `network-timeout` du lecteur, après lequel mpv abandonne.
const Duration _releaseWait = Duration(seconds: 15);
const Duration _releasePause = Duration(milliseconds: 400);

/// Un serveur éteint doit échouer vite : mpv attend ici bien plus longtemps.
const Duration _connectTimeout = Duration(seconds: 10);

const int _mebibyte = 1024 * 1024;

/// Seul un tiers de la fenêtre est lu à l'avance : le reste garde ce que le
/// lecteur vient de recevoir, qu'il redemande quand il change de piste.
const int _aheadShare = 3;

/// Un saut en avant plus court se lit à la suite : c'est plus rapide que de
/// changer de connexion.
const int _skipBytes = 8 * _mebibyte;

/// Taille des morceaux remis au lecteur.
const int _readBytes = 64 * 1024;

/// Ces listes renvoient vers d'autres adresses, que le relais ne connaît pas.
const List<String> _playlistExtensions = ['.m3u8', '.m3u', '.mpd'];
const String _playlistType = 'mpegurl';

/// En-têtes du lecteur transmis au serveur.
const List<String> _requestHeaders = [
  HttpHeaders.userAgentHeader,
  HttpHeaders.acceptHeader,
];

enum _Command { release, close }

/// Relais local des flux, qui garde une seule connexion vers le serveur.
///
/// Un abonnement limité à une connexion refuse la seconde (HTTP 458), et une
/// connexion coupée met du temps à se libérer. Or mpv saute souvent dans un
/// film : pour lire son index à l'ouverture, puis à chaque piste choisie, car il
/// vide alors son tampon et relit ce qu'il avait déjà. FFmpeg ouvre pour cela
/// une seconde connexion avant de fermer la première, et aucune option ne change
/// cet ordre : le lecteur se bloque lui-même.
///
/// Le relais coupe d'abord l'ancienne connexion, et garde une fenêtre du film en
/// mémoire : un saut qui y reste n'en ouvre aucune, et ne se voit donc pas.
///
/// Un direct passe aussi par lui : le serveur reçoit une demande sans position,
/// et le lecteur un flux sans taille, dans lequel il n'essaie pas de se déplacer.
///
/// Il tourne dans son propre isolate : copier un film ne doit pas ralentir
/// l'interface d'un stick. Le lecteur ne voit ainsi qu'une adresse locale, sans
/// le mot de passe du compte.
final class StreamRelay {
  StreamRelay._(this._commands, this._port);

  final SendPort _commands;
  final int _port;

  /// La fenêtre n'occupe sa mémoire qu'à l'ouverture du premier film.
  static Future<StreamRelay> start({int windowBytes = 32 * _mebibyte}) async {
    final ready = ReceivePort();
    await Isolate.spawn(
      _serve,
      (ready.sendPort, windowBytes),
      debugName: 'StreamRelay',
      errorsAreFatal: false,
    );
    final answer = await ready.first as (SendPort, int);
    return StreamRelay._(answer.$1, answer.$2);
  }

  /// Faux pour les adresses que le lecteur doit ouvrir lui-même.
  static bool canCarry(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('http') && !uri.isScheme('https')) {
      return false;
    }
    final path = uri.path.toLowerCase();
    return !_playlistExtensions.any(path.endsWith);
  }

  /// Retourne l'adresse locale à ouvrir à la place de [stream].
  Future<String> addressOf(ResolvedStream stream, {bool live = false}) async {
    final reply = ReceivePort();
    _commands.send((stream.url, stream.headers, live, reply.sendPort));
    await reply.first;
    final path = Uri.parse(stream.url).pathSegments;
    final name = path.isEmpty ? '' : path.last;
    final dot = name.lastIndexOf('.');
    return 'http://127.0.0.1:$_port/film${dot < 0 ? '' : name.substring(dot)}';
  }

  /// Rend la connexion au serveur, quand le lecteur abandonne le flux.
  void release() => _commands.send(_Command.release);

  /// Coupe la connexion au serveur et arrête l'isolate.
  void close() => _commands.send(_Command.close);
}

Future<void> _serve((SendPort, int) setup) async {
  final (host, windowBytes) = setup;
  final commands = ReceivePort();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final relay = _Relay(windowBytes);
  server.listen((request) => unawaited(relay.handle(request)));
  commands.listen((message) {
    switch (message) {
      case (
        final String url,
        final Map<String, String> headers,
        final bool live,
        final SendPort reply,
      ):
        relay.target(Uri.parse(url), headers, live: live);
        reply.send(null);
      case _Command.release:
        relay.stop();
      case _Command.close:
        relay.stop();
        unawaited(server.close(force: true));
        commands.close();
    }
  });
  host.send((commands.sendPort, server.port));
}

/// Mémoire circulaire de taille fixe, autour de la position lue dans le fichier.
final class _Window {
  _Window(int capacity) : _bytes = Uint8List(capacity);

  final Uint8List _bytes;

  /// Partie du fichier présente en mémoire.
  int start = 0;
  int end = 0;

  /// Taille du fichier, nulle tant qu'aucun film n'est ouvert.
  int size = 0;

  /// Le serveur sait reprendre le fichier à une position donnée.
  bool seekable = false;

  /// Position jusqu'à laquelle le lecteur a reçu le fichier.
  int reader = 0;
  Completer<void>? _waiting;

  int get aheadLimit => _bytes.length ~/ _aheadShare;

  void restart(int position, {required int size, required bool seekable}) {
    start = position;
    end = position;
    reader = position;
    this.size = size;
    this.seekable = seekable;
  }

  void add(List<int> chunk) {
    final capacity = _bytes.length;
    final offset = end % capacity;
    final first = min(chunk.length, capacity - offset);
    _bytes.setRange(offset, offset + first, chunk);
    _bytes.setRange(0, chunk.length - first, chunk, first);
    end += chunk.length;
    start = max(start, end - capacity);
  }

  /// Une copie : ce qui attend de partir vers le lecteur ne doit pas être écrasé.
  Uint8List? read(int position) {
    if (position < start || position >= end) return null;
    final offset = position % _bytes.length;
    final length = min(_readBytes, min(end - position, _bytes.length - offset));
    return _bytes.sublist(offset, offset + length);
  }

  /// Se termine à la prochaine nouveauté : données reçues ou demande annulée.
  Future<void> get changed => (_waiting ??= Completer()).future;

  void wake() {
    _waiting?.complete();
    _waiting = null;
  }
}

final class _Relay {
  _Relay(this._windowBytes);

  final int _windowBytes;
  Uri? _target;
  Map<String, String> _headers = const {};
  bool _live = false;

  /// En-têtes du lecteur, repris si la connexion doit être rouverte.
  Map<String, String> _asked = const {};
  HttpClient? _upstream;
  StreamSubscription<List<int>>? _feed;
  _Window? _window;
  String? _contentType;

  /// Dernière position de reprise : un serveur qui ne livre plus rien ne doit
  /// pas être relancé sans fin.
  int? _resumedFrom;

  /// Augmente à chaque demande : seule la dernière a encore de l'intérêt.
  int _demand = 0;

  void target(Uri url, Map<String, String> headers, {required bool live}) {
    stop();
    _target = url;
    _headers = headers;
    _live = live;
  }

  void stop() {
    _demand++;
    _cut();
    _window
      ?..restart(0, size: 0, seekable: false)
      ..wake();
  }

  void _cut() {
    unawaited(_feed?.cancel());
    _feed = null;
    _upstream?.close(force: true);
    _upstream = null;
  }

  /// Même politique que mpv, qui ne vérifie pas les certificats : les panneaux
  /// en https en ont rarement un valide.
  HttpClient _connect() {
    final client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = _connectTimeout
      ..badCertificateCallback = ((_, _, _) => true);
    _upstream = client;
    return client;
  }

  Future<void> handle(HttpRequest request) async {
    final response = request.response..persistentConnection = false;
    // Le lecteur peut couper à tout moment : ce n'est pas une erreur.
    unawaited(response.done.then<void>((_) {}, onError: (Object _) {}));
    final url = _target;
    if (url == null) {
      response.statusCode = HttpStatus.notFound;
      await _finish(response);
      return;
    }

    final demand = ++_demand;
    final window = _window?..wake();
    final position = _live ? null : _positionAsked(request);
    _asked = {
      for (final name in _requestHeaders)
        if (request.headers.value(name) case final String value) name: value,
    };
    try {
      if (window != null && _covers(window, position ?? 0)) {
        await _answer(
          response,
          window,
          position ?? 0,
          demand,
          partial: position != null,
        );
        return;
      }
      // Une connexion vient d'être coupée : le panneau la croit encore active.
      final replacing = _upstream != null;
      _cut();
      final client = _connect();
      final answer = await _open(
        client,
        url,
        position,
        demand,
        waitForRelease: replacing,
      );
      if (answer == null) {
        if (identical(_upstream, client)) _cut();
        await _finish(response);
      } else if (_isPlaylist(answer)) {
        await _redirectToPlaylist(answer, url, response);
      } else if (_sizeOf(answer) case final int size when !_live) {
        final partial = answer.statusCode == HttpStatus.partialContent;
        final start = partial ? position ?? 0 : 0;
        final opened = _window ??= _Window(_windowBytes);
        opened.restart(
          start,
          size: size,
          seekable:
              partial ||
              answer.headers.value(HttpHeaders.acceptRangesHeader) != null,
        );
        _contentType = answer.headers.value(HttpHeaders.contentTypeHeader);
        _resumedFrom = null;
        _fill(opened, answer);
        await _answer(response, opened, start, demand, partial: partial);
      } else {
        await _forward(answer, response);
      }
    } on IOException {
      await _fail(response);
    }
  }

  static int? _positionAsked(HttpRequest request) {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    final match = RegExp(r'^bytes=(\d+)-$').firstMatch(range ?? '');
    return match == null ? null : int.parse(match[1]!);
  }

  bool _covers(_Window window, int position) {
    final reach = _feed == null ? window.end : window.end + _skipBytes;
    return position < window.size &&
        position >= window.start &&
        position <= reach;
  }

  bool _isPlaylist(HttpClientResponse answer) =>
      answer.headers
          .value(HttpHeaders.contentTypeHeader)
          ?.toLowerCase()
          .contains(_playlistType) ??
      false;

  /// Une liste sans extension reconnaissable : le lecteur la lira lui-même.
  Future<void> _redirectToPlaylist(
    HttpClientResponse answer,
    Uri url,
    HttpResponse response,
  ) async {
    final location = answer.redirects.isEmpty
        ? url
        : answer.redirects.last.location;
    _cut();
    await response.redirect(location);
  }

  /// Taille du fichier, si le serveur l'annonce.
  static int? _sizeOf(HttpClientResponse answer) {
    if (answer.statusCode == HttpStatus.partialContent) {
      final range = answer.headers.value(HttpHeaders.contentRangeHeader);
      return range == null ? null : int.tryParse(range.split('/').last);
    }
    final known =
        answer.statusCode == HttpStatus.ok && answer.contentLength > 0;
    return known ? answer.contentLength : null;
  }

  Future<HttpClientResponse?> _open(
    HttpClient client,
    Uri url,
    int? position,
    int demand, {
    required bool waitForRelease,
  }) async {
    final clock = Stopwatch()..start();
    while (demand == _demand) {
      final upstream = await client.getUrl(url);
      _asked.forEach(upstream.headers.set);
      if (position != null) {
        upstream.headers.set(HttpHeaders.rangeHeader, 'bytes=$position-');
      }
      _headers.forEach(upstream.headers.set);
      final answer = await upstream.close();
      if (demand != _demand) return null;
      final refused = answer.statusCode == _connectionsFull;
      if (!refused || !waitForRelease || clock.elapsed > _releaseWait) {
        return answer;
      }
      await answer.drain<void>();
      await Future<void>.delayed(_releasePause);
    }
    return null;
  }

  /// Le serveur remplit la fenêtre, au rythme du lecteur.
  void _fill(_Window window, HttpClientResponse answer) {
    void ended() {
      _feed = null;
      window.wake();
    }

    _feed = answer.listen(
      (chunk) {
        window
          ..add(chunk)
          ..wake();
        _regulate(window);
      },
      onError: (Object _) => ended(),
      onDone: ended,
      cancelOnError: true,
    );
  }

  /// Hors de cette limite, le serveur attend : la mémoire reste bornée, et ce
  /// que le lecteur n'a pas encore lu n'est jamais écrasé.
  void _regulate(_Window window) {
    final feed = _feed;
    if (feed == null) return;
    final full = window.end - window.reader >= window.aheadLimit;
    if (full && !feed.isPaused) feed.pause();
    if (!full && feed.isPaused) feed.resume();
  }

  Future<void> _answer(
    HttpResponse response,
    _Window window,
    int position,
    int demand, {
    required bool partial,
  }) async {
    window.reader = position;
    _regulate(window);
    response
      ..statusCode = partial ? HttpStatus.partialContent : HttpStatus.ok
      ..contentLength = window.size - position;
    final headers = response.headers;
    if (_contentType case final String type) {
      headers.set(HttpHeaders.contentTypeHeader, type);
    }
    if (window.seekable) headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (partial) {
      headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $position-${window.size - 1}/${window.size}',
      );
    }
    await response.addStream(_read(window, position, demand));
    await _finish(response);
  }

  Stream<List<int>> _read(_Window window, int from, int demand) async* {
    var position = from;
    while (demand == _demand && position < window.size) {
      final bytes = window.read(position);
      if (bytes != null) {
        position += bytes.length;
        window.reader = position;
        _regulate(window);
        yield bytes;
      } else if (_feed != null) {
        await window.changed;
      } else if (!await _resume(window, demand)) {
        return;
      }
    }
  }

  /// Le serveur a fermé avant la fin du fichier, souvent après une longue pause.
  Future<bool> _resume(_Window window, int demand) async {
    final url = _target;
    final from = window.end;
    if (url == null || from == _resumedFrom) return false;
    _resumedFrom = from;
    _cut();
    final client = _connect();
    try {
      final answer = await _open(
        client,
        url,
        from,
        demand,
        waitForRelease: true,
      );
      if (answer?.statusCode == HttpStatus.partialContent) {
        _fill(window, answer!);
        return true;
      }
    } on IOException {
      // Le lecteur recevra un fichier écourté, et le signalera.
    }
    if (identical(_upstream, client)) _cut();
    return false;
  }

  /// Une réponse telle quelle : un refus, ou un flux sans taille. Un direct ne
  /// dit ni sa taille ni qu'il sait reprendre : le lecteur chercherait à s'y
  /// déplacer, et ouvrirait une seconde connexion.
  Future<void> _forward(
    HttpClientResponse answer,
    HttpResponse response,
  ) async {
    response.statusCode = answer.statusCode;
    if (!_live && answer.contentLength >= 0) {
      response.contentLength = answer.contentLength;
    }
    final type = answer.headers.value(HttpHeaders.contentTypeHeader);
    if (type != null) {
      response.headers.set(HttpHeaders.contentTypeHeader, type);
    }
    await response.addStream(answer);
    await _finish(response);
  }

  /// Le serveur est injoignable, ou le lecteur vient de couper.
  Future<void> _fail(HttpResponse response) async {
    try {
      response.statusCode = HttpStatus.badGateway;
    } on StateError {
      // Les en-têtes sont déjà partis : il ne reste qu'à fermer.
    }
    await _finish(response);
  }

  Future<void> _finish(HttpResponse response) async {
    try {
      await response.close();
    } on IOException {
      return;
    } on StateError {
      return;
    }
  }
}
