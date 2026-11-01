import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Panneau qui, comme un vrai, n'accepte qu'une connexion par compte.
///
/// Toute demande reçue pendant qu'une autre est active est refusée en 458. Le
/// fichier répond aux reprises, comme une VOD. Il travaille directement sur le
/// socket : `HttpServer` ne signale pas qu'un client a coupé en cours d'écriture,
/// et le panneau croirait à tort la connexion encore occupée.
final class OneConnectionPanel {
  OneConnectionPanel._(
    this._server,
    this._file, {
    required this.releaseDelay,
    required this.refuseAll,
    required this.announcesSize,
    required this.refusesRanges,
  });

  static Future<OneConnectionPanel> start(
    Uint8List file, {
    Duration releaseDelay = Duration.zero,
    bool refuseAll = false,
    bool announcesSize = true,
    bool refusesRanges = false,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final panel = OneConnectionPanel._(
      server,
      file,
      releaseDelay: releaseDelay,
      refuseAll: refuseAll,
      announcesSize: announcesSize,
      refusesRanges: refusesRanges,
    );
    server.listen((socket) => unawaited(panel._serve(socket)));
    return panel;
  }

  final ServerSocket _server;
  final Uint8List _file;
  final Set<Socket> _sockets = {};

  /// Délai entre la coupure d'une connexion et sa libération côté panneau.
  final Duration releaseDelay;

  /// Une autre application occupe déjà le compte.
  bool refuseAll;

  /// Comme un direct, le flux n'a pas de taille.
  final bool announcesSize;

  /// Comme certains serveurs de direct, une demande avec position est refusée.
  final bool refusesRanges;

  /// Délai avant la réponse, comme une chaîne que le serveur doit réveiller.
  Duration answerDelay = Duration.zero;
  final List<String?> ranges = [];
  final List<String?> identities = [];
  int active = 0;
  int mostActive = 0;
  int refused = 0;

  /// Octets confiés aux sockets.
  int sent = 0;

  /// Le compte n'a plus droit à rien.
  void refuseEverything() => refuseAll = true;

  /// Coupe les connexions en cours, comme après une longue pause.
  void dropConnections() {
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
  }

  String get url =>
      'http://127.0.0.1:${_server.port}/movie/compte/secret/1.mp3';

  Future<void> _serve(Socket socket) async {
    _sockets.add(socket);
    final head = StringBuffer();
    final request = Completer<void>();
    final gone = Completer<void>();
    socket.listen(
      (bytes) {
        head.write(latin1.decode(bytes));
        if (head.toString().contains('\r\n\r\n') && !request.isCompleted) {
          request.complete();
        }
      },
      onError: (Object _) {
        if (!gone.isCompleted) gone.complete();
      },
      onDone: () {
        if (!gone.isCompleted) gone.complete();
      },
      cancelOnError: true,
    );
    await Future.any([request.future, gone.future]);
    if (!request.isCompleted) return;

    String? header(String name) => RegExp(
      '^$name: *(.*)\$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(head.toString().replaceAll('\r', ''))?.group(1);

    final range = header('range');
    ranges.add(range);
    identities.add(header('user-agent'));
    if (refusesRanges && range != null) {
      socket.write('HTTP/1.1 416 Range\r\nContent-Length: 0\r\n\r\n');
      await socket.close();
      _sockets.remove(socket);
      return;
    }
    if (active > 0 || refuseAll) {
      refused++;
      socket.write('HTTP/1.1 458 Occupied\r\nContent-Length: 0\r\n\r\n');
      await socket.close();
      _sockets.remove(socket);
      return;
    }

    active++;
    if (active > mostActive) mostActive = active;
    await Future<void>.delayed(answerDelay);
    final match = RegExp(r'bytes=(\d+)-').firstMatch(range ?? '');
    final start = match == null ? 0 : int.parse(match[1]!);
    final length = _file.length - start;
    socket.write(
      announcesSize
          ? '${match == null ? 'HTTP/1.1 200 OK' : 'HTTP/1.1 206 Partial Content'}'
                '\r\nContent-Type: audio/mpeg\r\nAccept-Ranges: bytes'
                '\r\nContent-Length: $length\r\n'
                '${match == null ? '' : 'Content-Range: bytes $start-${_file.length - 1}/${_file.length}\r\n'}'
                '\r\n'
          : 'HTTP/1.1 200 OK\r\nContent-Type: video/mp2t\r\n\r\n',
    );
    try {
      for (
        var at = start;
        at < _file.length && !gone.isCompleted;
        at += 65536
      ) {
        final end = (at + 65536).clamp(0, _file.length);
        socket.add(Uint8List.sublistView(_file, at, end));
        sent += end - at;
        // `flush` reste bloqué tant que le client ne lit pas, même s'il coupe.
        await Future.any([socket.flush(), gone.future]);
      }
      if (!gone.isCompleted) await socket.close();
    } on Object {
      // Le client a coupé pendant l'écriture.
    } finally {
      socket.destroy();
      _sockets.remove(socket);
      await Future<void>.delayed(releaseDelay);
      active--;
    }
  }

  Future<void> close() async {
    await _server.close();
    for (final socket in _sockets.toList()) {
      socket.destroy();
    }
  }
}
