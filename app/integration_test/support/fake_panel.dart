import 'dart:convert';
import 'dart:io';

const int _categories = 40;
const int _chunk = 500;

/// Chaque titre existe en quatre langues, comme dans un vrai catalogue.
const List<String> _languages = ['FR', 'EN', 'DE', 'ES'];
const List<String> _articles = ['Le', 'The', 'Der', 'El'];

/// Panneau Xtream factice, servi depuis l'appareil lui-même.
///
/// Il produit ses listes à la volée, sans jamais les garder en mémoire, et sait
/// reproduire deux pannes de panneau réel : une réponse coupée en route, et la
/// réponse de connexion renvoyée à la place d'une liste.
final class FakePanel {
  FakePanel._(
    this._server, {
    required this.channels,
    required this.movies,
    required this.series,
    required this.cutsChannelsOnce,
    required this.refusesSeries,
  });

  static Future<FakePanel> start({
    required int channels,
    required int movies,
    required int series,
    bool cutsChannelsOnce = false,
    bool refusesSeries = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final panel = FakePanel._(
      server,
      channels: channels,
      movies: movies,
      series: series,
      cutsChannelsOnce: cutsChannelsOnce,
      refusesSeries: refusesSeries,
    );
    server.listen(panel._handle);
    return panel;
  }

  final HttpServer _server;
  final int channels;
  final int movies;
  final int series;

  /// La première liste de chaînes s'arrête à la moitié.
  final bool cutsChannelsOnce;

  /// La liste des séries est refusée, à chaque demande.
  final bool refusesSeries;

  /// Demandes reçues pour chaque liste.
  final Map<String, int> calls = {};

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final action = request.uri.queryParameters['action'];
    final response = request.response..headers.contentType = ContentType.json;
    final call = calls.update(
      action ?? '',
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    try {
      switch (action) {
        case null:
          response.write(jsonEncode(_login(auth: 1)));
        case 'get_live_streams':
          await _list(
            response,
            cutsChannelsOnce && call == 1 ? channels ~/ 2 : channels,
            _channel,
            closed: !(cutsChannelsOnce && call == 1),
          );
        case 'get_vod_streams':
          await _list(response, movies, _movie);
        case 'get_series' when refusesSeries:
          response.write(jsonEncode(_login(auth: 0)));
        case 'get_series':
          await _list(response, series, _show);
        default:
          response.write(
            jsonEncode([
              for (var i = 0; i < _categories; i++)
                {'category_id': '$i', 'category_name': 'FR | GROUPE $i'},
            ]),
          );
      }
      await response.close();
    } on IOException {
      // Le client a coupé : rien à lui répondre.
    }
  }

  Map<String, Object?> _login({required int auth}) => {
    'user_info': {'auth': auth, 'status': 'Active'},
    'server_info': {'url': '127.0.0.1'},
  };

  /// [closed] à `false` laisse la liste ouverte, comme une réponse coupée.
  Future<void> _list(
    HttpResponse response,
    int count,
    Map<String, Object?> Function(int index) item, {
    bool closed = true,
  }) async {
    response.write('[');
    for (var i = 0; i < count; i += _chunk) {
      final chunk = StringBuffer();
      for (var j = i; j < i + _chunk && j < count; j++) {
        if (j > 0) chunk.write(',');
        chunk.write(jsonEncode(item(j)));
      }
      response.write(chunk);
      // Le client impose son rythme, comme sur un vrai réseau.
      await response.flush();
    }
    if (closed) response.write(']');
  }

  Map<String, Object?> _channel(int i) => {
    'num': i,
    'name': 'FR: Chaîne ${i ~/ 3} ${const ['FHD', 'HD', 'SD'][i % 3]}',
    'stream_type': 'live',
    'stream_id': i,
    'stream_icon': '',
    'epg_channel_id': 'c${i ~/ 3}.fr',
    'category_id': '${i % _categories}',
  };

  Map<String, Object?> _movie(int i) {
    final language = i % _languages.length;
    final title = i ~/ _languages.length;
    return {
      'num': i,
      'name':
          '${_languages[language]} - ${_articles[language]} Film $title '
          '(${1980 + title % 45})',
      'stream_type': 'movie',
      'stream_id': i,
      'stream_icon': '',
      'rating': '7.1',
      'added': '1700000000',
      'container_extension': 'mkv',
      'category_id': '${i % _categories}',
    };
  }

  Map<String, Object?> _show(int i) {
    final language = i % _languages.length;
    final title = i ~/ _languages.length;
    return {
      'num': i,
      'name': '${_languages[language]} - ${_articles[language]} Série $title',
      'series_id': i,
      'cover': '',
      'plot':
          'Une famille découvre que la marée ne redescend plus, et que le '
          'village voisin a disparu des cartes.',
      'cast': 'Ana Reis, Marc Aubin, Lise Tran, Omar Diallo',
      'genre': 'Drame',
      'tmdb': '$title',
      'category_id': '${i % _categories}',
    };
  }
}
