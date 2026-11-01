// Cherche par quel chemin un panneau Xtream accepte de livrer son catalogue.
//
// Le compte arrive par la variable AERO_PROBE_ACCOUNT, en JSON encodé base64 :
// il n'est ni enregistré ni affiché. Lancé par tool/diagnostic_xtream.ps1.
//
// Compilé en exécutable : son terminal peut ne pas voir le cache de pub, que
// l'application Claude range dans son espace privé.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:iptv_data/src/adapters/http_text_stream.dart';
import 'package:iptv_domain/iptv_domain.dart';

/// Une rafale d'appels pourrait déclencher la protection du panneau.
const Duration _pause = Duration(milliseconds: 1200);

/// Un port fermé ne doit pas bloquer le rapport : seul le début est attendu.
const Duration _callTimeout = Duration(seconds: 25);

/// Identités essayées sur les flux, celle du lecteur d'abord.
const Map<String, String> _streamIdentities = {
  'Lecteur': 'libmpv',
  'Application': appUserAgent,
  'VLC': 'VLC/3.0.20 LibVLC/3.0.20',
};

/// Un compte n'a parfois droit qu'à une connexion : le panneau doit la libérer.
const Duration _streamPause = Duration(seconds: 3);
const int _maxRedirects = 5;

/// Code renvoyé par les panneaux quand toutes les connexions sont occupées.
const int _connectionsFull = 458;

/// Mêmes réglages que le relais du lecteur.
const Duration _releasePoll = Duration(milliseconds: 400);
const Duration _releaseLimit = Duration(seconds: 30);

/// Durée de lecture du début d'un film pour mesurer le débit.
const Duration _speedWindow = Duration(seconds: 6);

/// Lecture de la fin d'un film : l'index d'un MKV ou d'un MP4 y tient souvent.
const int _tailBytes = 1024 * 1024;
const int _bitsPerByte = 8;

const int _bodyPreview = 120;
const int _maxDetails = 8;
const String _sampleAction = 'get_live_categories';

const Map<String, String> _headers = {
  'User-Agent': 'okhttp/4.12.0',
  'Accept': '*/*',
};

/// Chemins essayés sur chaque adresse.
const List<String> _routes = [
  'GET http',
  'GET https',
  'POST http',
  'POST https',
  'GET + cookie',
  'M3U get.php',
  'Guide xmltv.php',
  'panel_api.php',
];

Future<void> main() async {
  final encoded = Platform.environment['AERO_PROBE_ACCOUNT'];
  if (encoded == null) {
    stderr.writeln(r'Lancez tool\diagnostic_xtream.ps1.');
    exitCode = 64;
    return;
  }
  final account = jsonDecode(utf8.decode(base64Decode(encoded))) as Map;
  final username = account['username'] as String;
  final password = account['password'] as String;
  final stored = ResolveStreamUrl.normalizeXtreamServer(
    account['serverUrl'] as String,
  );
  final others = (Platform.environment['AERO_PROBE_SERVERS'] ?? '')
      .split(',')
      .where((server) => server.trim().isNotEmpty)
      .map(ResolveStreamUrl.normalizeXtreamServer);
  final servers = {stored, ...others}.toList();

  /// Un serveur peut recopier la requête dans ses réponses.
  String clean(Object? value) => '$value'
      .replaceAll(username, '***')
      .replaceAll(password, '***')
      .replaceAll(Uri.encodeComponent(password), '***')
      .replaceAll(RegExp(r'\s+'), ' ');

  Map<String, String> query(String? action) => {
    'username': username,
    'password': password,
    'action': ?action,
  };

  final client = http.Client();
  final details = <String>{};
  final announced = await _describeAccount(
    client,
    Uri.parse('$stored/player_api.php').replace(queryParameters: query(null)),
    clean,
  );
  if (announced != null && !servers.contains(announced)) {
    servers.add(announced);
  }

  await _describeStreams(
    client,
    login: Uri.parse('$stored/player_api.php'),
    query: query,
    servers: {stored, ?announced},
    account:
        '${Uri.encodeComponent(username)}/'
        '${Uri.encodeComponent(password)}',
    clean: clean,
  );

  http.BaseRequest getWith(
    String server,
    String script,
    Map<String, String> args,
  ) => http.Request(
    'GET',
    Uri.parse('$server/$script').replace(queryParameters: args),
  )..headers.addAll(_headers);

  http.BaseRequest post(String server) =>
      http.Request('POST', Uri.parse('$server/player_api.php'))
        ..headers.addAll(_headers)
        ..bodyFields = query(_sampleAction);

  String secure(String server) => server.replaceFirst('http://', 'https://');

  final columns = <String>[];
  final cells = {for (final route in _routes) route: <String>[]};
  for (final server in servers) {
    final host = Uri.parse(server).host.split('.').first;
    columns.add(server == announced ? 'annonce' : host);
    final cookie = await _sessionCookie(
      client,
      getWith(server, 'player_api.php', query(null)),
    );
    final calls = <String, http.BaseRequest?>{
      'GET http': getWith(server, 'player_api.php', query(_sampleAction)),
      'GET https': getWith(
        secure(server),
        'player_api.php',
        query(_sampleAction),
      ),
      'POST http': post(server),
      'POST https': post(secure(server)),
      'GET + cookie': cookie == null
          ? null
          : (getWith(server, 'player_api.php', query(_sampleAction))
              ..headers['Cookie'] = cookie),
      'M3U get.php': getWith(server, 'get.php', {
        'username': username,
        'password': password,
        'type': 'm3u_plus',
        'output': 'ts',
      }),
      'Guide xmltv.php': getWith(server, 'xmltv.php', {
        'username': username,
        'password': password,
      }),
      'panel_api.php': getWith(server, 'panel_api.php', query(null)),
    };
    for (final route in _routes) {
      final request = calls[route];
      cells[route]!.add(
        request == null
            ? 'sans cookie'
            : await _probe(
                client,
                request,
                (text) => details.length < _maxDetails
                    ? details.add('$route / $host : ${clean(text)}')
                    : null,
              ),
      );
      await Future<void>.delayed(_pause);
    }
  }
  client.close();

  _printTable(columns, cells);
  if (details.isNotEmpty) {
    stdout.writeln('\nReponses refusees :');
    details.forEach(stdout.writeln);
  }
  stdout.writeln(
    '\nCe rapport ne contient ni votre nom ni votre mot de passe : '
    'vous pouvez le partager.',
  );
}

void _printTable(List<String> columns, Map<String, List<String>> cells) {
  final widths = [
    for (var column = 0; column < columns.length; column++)
      cells.values
          .map((row) => row[column].length)
          .followedBy([columns[column].length])
          .reduce((a, b) => a > b ? a : b),
  ];
  String line(String first, List<String> values) => [
    first.padRight(16),
    for (var column = 0; column < values.length; column++)
      values[column].padRight(widths[column]),
  ].join('  ');

  stdout.writeln('\nReponse selon le chemin et l adresse :');
  stdout.writeln(line('Chemin', columns));
  cells.forEach((route, row) => stdout.writeln(line(route, row)));
}

/// Affiche l'état du compte. Retourne le serveur annoncé par le panneau.
Future<String?> _describeAccount(
  http.Client client,
  Uri login,
  String Function(Object?) clean,
) async {
  final response = await client
      .send(http.Request('GET', login)..headers.addAll(_headers))
      .timeout(catalogResponseTimeout);
  final body = await response.stream.bytesToString();
  stdout.writeln('Connexion : HTTP ${response.statusCode}');
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    stdout.writeln('Reponse illisible.');
    return null;
  }
  if (json is! Map) return null;
  final user = json['user_info'];
  final server = json['server_info'];
  if (user is Map) {
    final expiry = int.tryParse('${user['exp_date']}');
    stdout
      ..writeln('Etat : ${clean(user['status'])}  auth=${clean(user['auth'])}')
      ..writeln(
        'Expiration : ${expiry == null ? 'aucune indiquee' : _date(expiry)}',
      )
      ..writeln('Essai : ${clean(user['is_trial'])}')
      ..writeln(
        'Connexions : ${clean(user['active_cons'])}'
        '/${clean(user['max_connections'])}',
      )
      ..writeln('Formats : ${clean(user['allowed_output_formats'])}')
      ..writeln('Message : ${clean(user['message'])}');
    final active = int.tryParse('${user['active_cons']}');
    final limit = int.tryParse('${user['max_connections']}');
    if (active != null && limit != null && active >= limit) {
      stdout.writeln(
        'Attention : toutes les connexions sont occupees, '
        'les flux seront refuses (souvent HTTP 458).',
      );
    }
  }
  final cookies = response.headers['set-cookie'];
  stdout.writeln(
    'Cookies : ${cookies == null ? 'aucun' : clean(_cookieNames(cookies))}',
  );
  if (server is! Map) return null;
  final url = clean(server['url']);
  final port = clean(server['port']);
  final scheme = server['server_protocol'] == 'https' ? 'https' : 'http';
  stdout.writeln(
    'Serveur annonce : $scheme://$url:$port  '
    '(https ${clean(server['https_port'])}, '
    'fuseau ${clean(server['timezone'])})',
  );
  if (url.isEmpty || url == 'null') return null;
  return '$scheme://$url${port.isEmpty || port == 'null' ? '' : ':$port'}';
}

/// Ouvre un flux direct et un film, comme le ferait le lecteur.
Future<void> _describeStreams(
  http.Client client, {
  required Uri login,
  required Map<String, String> Function(String? action) query,
  required Set<String> servers,
  required String account,
  required String Function(Object?) clean,
}) async {
  Future<List<Object?>> list(Map<String, String> args) async {
    final request = http.Request('GET', login.replace(queryParameters: args))
      ..headers.addAll(_headers);
    final response = await client.send(request).timeout(catalogResponseTimeout);
    final body = await response.stream.bytesToString();
    if (response.statusCode != HttpStatus.ok) return const [];
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return const [];
    }
    return json is List ? json : const [];
  }

  /// Premier titre de la première catégorie : la liste complète pèse trop lourd.
  Future<Map<Object?, Object?>?> sample(String kind) async {
    final categories = await list(query('get_${kind}_categories'));
    final first = categories.whereType<Map<Object?, Object?>>().firstOrNull;
    if (first == null) return null;
    final items = await list({
      ...query('get_${kind}_streams'),
      'category_id': '${first['category_id']}',
    });
    return items.whereType<Map<Object?, Object?>>().firstOrNull;
  }

  final live = await sample('live');
  final vod = await sample('vod');
  final streams = {
    if (live != null) 'Direct': 'live/$account/${live['stream_id']}.ts',
    if (vod != null)
      'Film':
          'movie/$account/${vod['stream_id']}.'
          '${vod['container_extension'] ?? 'mp4'}',
  };

  stdout.writeln('\nOuverture des flux, debut seulement :');
  if (streams.isEmpty) {
    stdout.writeln('Aucun flux d exemple : le catalogue est refuse.');
    return;
  }
  for (final server in servers) {
    stdout.writeln(Uri.parse(server).host);
    for (final stream in streams.entries) {
      for (final identity in _streamIdentities.entries) {
        final result = await _openStream(
          Uri.parse('$server/${stream.value}'),
          identity.value,
        );
        stdout.writeln(
          '  ${stream.key.padRight(7)} ${identity.key.padRight(12)} '
          '${clean(result)}',
        );
        await Future<void>.delayed(_streamPause);
      }
    }
  }

  final server = servers.first;
  stdout.writeln('\nMesures de lecture :');
  final film = streams['Film'];
  if (film != null) await _measureFilm(Uri.parse('$server/$film'), clean);
  final direct = streams['Direct'];
  if (direct != null) await _measureLive(Uri.parse('$server/$direct'), clean);
}

String _seconds(Duration value) =>
    '${(value.inMilliseconds / 1000).toStringAsFixed(1)} s';

/// Connexion ouverte, à fermer avec [close].
final class _Stream {
  _Stream(this._client, this.answer, this.toHeaders);

  final HttpClient _client;
  final HttpClientResponse answer;
  final Duration toHeaders;

  void close() => _client.close(force: true);
}

Future<_Stream> _request(Uri url, Map<String, String> headers) async {
  final clock = Stopwatch()..start();
  final client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = _callTimeout
    ..badCertificateCallback = ((_, _, _) => true);
  try {
    final request = await client.getUrl(url).timeout(_callTimeout);
    headers.forEach(request.headers.set);
    final answer = await request.close().timeout(_callTimeout);
    return _Stream(client, answer, clock.elapsed);
  } on Object {
    client.close(force: true);
    rethrow;
  }
}

/// Répète la demande tant que le panneau répond que la connexion est occupée.
Future<(_Stream, Duration, int)> _whenReleased(
  Uri url,
  Map<String, String> headers,
) async {
  final clock = Stopwatch()..start();
  var refused = 0;
  for (;;) {
    final stream = await _request(url, headers);
    if (stream.answer.statusCode != _connectionsFull ||
        clock.elapsed > _releaseLimit) {
      return (stream, clock.elapsed, refused);
    }
    stream.close();
    refused++;
    await Future<void>.delayed(_releasePoll);
  }
}

/// Refait ce que fait le lecteur à l'ouverture d'un MKV : le début, la fin, puis
/// de nouveau le début. Chaque changement de connexion est chronométré.
Future<void> _measureFilm(Uri url, String Function(Object?) clean) async {
  const identity = {'User-Agent': 'libmpv', 'Accept': '*/*'};
  try {
    final total = Stopwatch()..start();
    final head = await _request(url, {...identity, 'Range': 'bytes=0-'});
    final status = head.answer.statusCode;
    final range = head.answer.headers.value(HttpHeaders.contentRangeHeader);
    final size = int.tryParse(range?.split('/').last ?? '');
    final type = head.answer.headers.value(HttpHeaders.contentTypeHeader);
    final clock = Stopwatch()..start();
    var bytes = 0;
    Duration? firstByte;
    try {
      await for (final chunk in head.answer.timeout(_callTimeout)) {
        firstByte ??= clock.elapsed;
        bytes += chunk.length;
        if (clock.elapsed > _speedWindow) break;
      }
    } on TimeoutException {
      stdout.writeln(
        '  Film : plus de donnees apres ${_seconds(clock.elapsed)}',
      );
    }
    final speed =
        bytes * _bitsPerByte / 1000 / 1000 / (clock.elapsedMilliseconds / 1000);
    head.close();
    stdout.writeln(
      '  Film : HTTP $status, en-tetes ${_seconds(head.toHeaders)}, '
      'premier octet ${firstByte == null ? 'jamais' : _seconds(firstByte)}, '
      '${speed.toStringAsFixed(1)} Mbit/s, '
      '${size == null ? 'taille inconnue' : '${size ~/ (1024 * 1024)} Mio'}, '
      'type ${clean(type)}',
    );
    if (size == null || status != HttpStatus.partialContent) {
      stdout.writeln(
        '  Film : le serveur ne reprend pas a une position donnee',
      );
      return;
    }

    final tailRange = 'bytes=${size - _tailBytes}-';
    final (tail, released, refused) = await _whenReleased(url, {
      ...identity,
      'Range': tailRange,
    });
    final tailClock = Stopwatch()..start();
    await tail.answer.drain<void>().timeout(_callTimeout);
    tail.close();
    stdout.writeln(
      '  Film : liberation apres coupure ${_seconds(released)} '
      '($refused refus), HTTP ${tail.answer.statusCode}, '
      'fin du fichier lue en ${_seconds(tailClock.elapsed)}',
    );

    final (back, releasedAtEnd, refusedAtEnd) = await _whenReleased(url, {
      ...identity,
      'Range': 'bytes=4096-',
    });
    back.close();
    stdout.writeln(
      '  Film : liberation apres fin normale ${_seconds(releasedAtEnd)} '
      '($refusedAtEnd refus), HTTP ${back.answer.statusCode}',
    );
    stdout.writeln(
      '  Film : ouverture avec index en fin de fichier ${_seconds(total.elapsed - _speedWindow)}',
    );
  } on Object catch (error) {
    stdout.writeln('  Film : mesure interrompue (${error.runtimeType})');
  }
  await Future<void>.delayed(_streamPause);
}

/// Compare la demande de mpv, qui échouait sur les directs, à celle du relais.
Future<void> _measureLive(Uri url, String Function(Object?) clean) async {
  const relay = {'User-Agent': 'libmpv', 'Accept': '*/*'};
  const asked = {
    'mpv seul': {...relay, 'Range': 'bytes=0-', 'Icy-MetaData': '1'},
    'relais': relay,
  };
  for (final demand in asked.entries) {
    final name = demand.key;
    try {
      final (stream, _, _) = await _whenReleased(url, demand.value);
      final clock = Stopwatch()..start();
      final answer = stream.answer;
      final first = await answer
          .firstWhere((chunk) => chunk.isNotEmpty, orElse: () => const [])
          .timeout(_callTimeout);
      final ranges = answer.headers.value(HttpHeaders.acceptRangesHeader);
      stdout.writeln(
        '  Direct ($name) : HTTP ${answer.statusCode}, '
        'en-tetes ${_seconds(stream.toHeaders)}, '
        'premier octet ${_seconds(clock.elapsed)}, '
        '${_contentKind(first)}, '
        'taille ${answer.contentLength}, reprise ${clean(ranges)}',
      );
      stream.close();
    } on TimeoutException {
      stdout.writeln('  Direct ($name) : trop long');
    } on Object catch (error) {
      stdout.writeln('  Direct ($name) : echec (${error.runtimeType})');
    }
    await Future<void>.delayed(_streamPause);
  }
}

/// Suit les redirections une à une, pour montrer où le refus se produit. Seul
/// l'hôte d'une redirection est affiché : son chemin contient le mot de passe.
Future<String> _openStream(Uri start, String userAgent) async {
  final steps = <String>[];
  final client = http.Client();
  var url = start;
  try {
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final request = http.Request('GET', url)
        ..followRedirects = false
        ..headers['User-Agent'] = userAgent
        ..headers['Accept'] = '*/*';
      final response = await client.send(request).timeout(_callTimeout);
      final status = response.statusCode;
      final location = response.headers['location'];
      if (status >= 300 && status < 400 && location != null) {
        url = url.resolve(location);
        steps.add('$status vers ${url.host}');
        continue;
      }
      final first = await response.stream
          .firstWhere((chunk) => chunk.isNotEmpty, orElse: () => const [])
          .timeout(_callTimeout);
      final server = response.headers['server'];
      steps.add(
        '$status ${_contentKind(first)}'
        '${server == null ? '' : ' ($server)'}',
      );
      return steps.join(', ');
    }
    steps.add('trop de redirections');
  } on TimeoutException {
    steps.add('trop long');
  } on HandshakeException {
    steps.add('tls refuse');
  } on Object catch (error) {
    steps.add(
      error is http.ClientException || error is SocketException
          ? 'sans reponse'
          : 'erreur ${error.runtimeType}',
    );
  } finally {
    client.close();
  }
  return steps.join(', ');
}

/// Nature des premiers octets : un flux vidéo, ou une page d'erreur.
String _contentKind(List<int> bytes) {
  if (bytes.isEmpty) return 'vide';
  final text = utf8.decode(bytes.take(16).toList(), allowMalformed: true);
  if (text.trimLeft().startsWith('<')) return 'page web';
  if (text.startsWith('#EXTM3U')) return 'liste hls';
  if (bytes.first == 0x47) return 'flux ts';
  if (text.contains('ftyp')) return 'flux mp4';
  if (bytes.length > 3 && bytes[0] == 0x1A && bytes[1] == 0x45) {
    return 'flux mkv';
  }
  return 'autre';
}

String _date(int seconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

List<String> _cookiePairs(String header) => [
  for (final cookie in header.split(RegExp(r',(?=[^;,]+=)')))
    cookie.split(';').first.trim(),
];

String _cookieNames(String header) =>
    _cookiePairs(header).map((pair) => pair.split('=').first).join(', ');

/// Cookie remis à la connexion, s'il y en a un.
Future<String?> _sessionCookie(
  http.Client client,
  http.BaseRequest login,
) async {
  try {
    final response = await client.send(login).timeout(_callTimeout);
    await response.stream.drain<void>();
    final header = response.headers['set-cookie'];
    return header == null ? null : _cookiePairs(header).join('; ');
  } on Object {
    return null;
  }
}

/// Retourne le résultat d'un appel, sans lire plus que son début.
Future<String> _probe(
  http.Client client,
  http.BaseRequest request,
  void Function(String text) onRefused,
) async {
  try {
    final response = await client.send(request).timeout(_callTimeout);
    final first = <int>[];
    await for (final chunk in response.stream.timeout(_callTimeout)) {
      first.addAll(chunk);
      if (first.isNotEmpty) break;
    }
    final preview = utf8.decode(
      first.take(_bodyPreview).toList(),
      allowMalformed: true,
    );
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      final hints = response.headers.entries
          .where((header) => header.key.startsWith('x-'))
          .map((header) => '${header.key}=${header.value}')
          .join(' ');
      onRefused(
        '$status, ${response.headers['content-type'] ?? 'sans type'}, '
        '${response.headers['server'] ?? 'serveur inconnu'} $hints '
        '| $preview',
      );
      return '$status';
    }
    final text = preview.trimLeft();
    final kind = switch (text) {
      '' => 'vide',
      _ when text.startsWith('#EXTM3U') => 'm3u',
      _ when text.startsWith('<') => 'xml',
      _ when text.startsWith('[') => 'liste',
      _ when text.startsWith('{') => 'objet',
      _ => 'autre',
    };
    return '$status $kind';
  } on TimeoutException {
    return 'trop long';
  } on HandshakeException {
    return 'tls refuse';
  } on Object catch (error) {
    return error is http.ClientException || error is SocketException
        ? 'sans reponse'
        : 'erreur ${error.runtimeType}';
  }
}
